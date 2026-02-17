import { createServer } from "node:http";
import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import cors from "cors";
import express from "express";
import { WebSocket, WebSocketServer } from "ws";
import {
  ApprovalDecisionInputSchema,
  ApplyRuntimeUpdateRequestSchema,
  CheckRuntimeUpdateRequestSchema,
  CreateSessionRequestSchema,
  CreateWorkflowRequestSchema,
  CreateWorktreeRequestSchema,
  RunWorkflowRequestSchema,
  SessionPromptRequestSchema,
  WaitSessionIdleRequestSchema,
  parseOrThrow,
} from "@agentpi/protocol";
import { DaemonEventBus } from "./lib/event-bus.js";
import { log } from "./lib/logger.js";
import { DevServerService } from "./modules/devserver/DevServerService.js";
import { RpcProcessPool } from "./modules/rpc/RpcProcessPool.js";
import { PiRuntimeUpdater } from "./modules/runtime/PiRuntimeUpdater.js";
import { SearchIndexer } from "./modules/search/SearchIndexer.js";
import { SessionManager } from "./modules/session/SessionManager.js";
import { StatsAggregator } from "./modules/stats/StatsAggregator.js";
import { PersistenceStore } from "./modules/storage/PersistenceStore.js";
import { TerminalService } from "./modules/terminal/TerminalService.js";
import { WorkflowEngine } from "./modules/workflow/WorkflowEngine.js";
import { WorktreeService } from "./modules/worktree/WorktreeService.js";

export interface DaemonApp {
  listen: (port?: number) => Promise<{ port: number }>;
  shutdown: () => Promise<void>;
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const LOCAL_ORIGIN_RE = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i;
const SHELL_ALLOWLIST = new Set(["bash", "zsh", "sh", "fish"]);
const COMMAND_ALLOWLIST = new Set(["npm", "pnpm", "yarn", "bun", "node", "npx"]);
const SAFE_ARG_RE = /^[\w./:=@+-]+$/;

function extractHttpToken(req: express.Request): string | null {
  const direct = req.header("x-agentpi-token");
  if (direct) return direct;

  const authHeader = req.header("authorization");
  if (!authHeader) return null;
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

function extractWsToken(urlText: string | undefined, headers: Record<string, string | string[] | undefined>): string | null {
  const fromHeader = headers["x-agentpi-token"];
  if (typeof fromHeader === "string" && fromHeader) return fromHeader;

  const authHeader = headers.authorization;
  if (typeof authHeader === "string") {
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    if (match?.[1]) return match[1];
  }

  if (!urlText) return null;
  try {
    const parsed = new URL(urlText, "http://127.0.0.1");
    const token = parsed.searchParams.get("token");
    return token && token.length > 0 ? token : null;
  } catch {
    return null;
  }
}

function isAllowedOrigin(origin: string | undefined): boolean {
  if (!origin || origin === "null") return true;
  return LOCAL_ORIGIN_RE.test(origin);
}

function asSafeDirectory(pathInput: string): string {
  const trimmed = pathInput.trim();
  if (!trimmed || trimmed.includes("\0")) {
    throw new Error("Invalid directory path");
  }
  if (!existsSync(trimmed)) {
    throw new Error(`Directory does not exist: ${trimmed}`);
  }
  return trimmed;
}

function validateShell(shell?: string): string | undefined {
  if (!shell) return undefined;
  const normalized = shell.split(/[\\/]/).pop() ?? shell;
  if (!SHELL_ALLOWLIST.has(normalized)) {
    throw new Error(`Shell ${shell} is not allowed`);
  }
  return shell;
}

function validateCommand(command: string, args: string[]): { command: string; args: string[] } {
  if (!COMMAND_ALLOWLIST.has(command)) {
    throw new Error(`Command ${command} is not allowed`);
  }
  if (args.length > 32) {
    throw new Error("Too many command args");
  }
  const normalizedArgs = args.map((arg) => {
    const value = arg.trim();
    if (!value || value.length > 256 || !SAFE_ARG_RE.test(value)) {
      throw new Error(`Invalid command arg: ${arg}`);
    }
    return value;
  });
  return { command, args: normalizedArgs };
}

export function createDaemonApp(): DaemonApp {
  const daemonToken = process.env.AGENTPI_DAEMON_TOKEN ?? randomUUID();
  process.env.AGENTPI_DAEMON_TOKEN = daemonToken;
  const startedAt = new Date().toISOString();
  let boundPort: number | null = null;
  let wsCurrentConnections = 0;
  let wsAcceptedConnections = 0;
  let wsRejectedConnections = 0;

  const app = express();
  app.use(
    cors({
      origin(origin, callback) {
        if (isAllowedOrigin(origin)) {
          callback(null, true);
          return;
        }
        callback(new Error("CORS origin not allowed"));
      },
    }),
  );
  app.use(express.json({ limit: "10mb" }));

  const store = new PersistenceStore(join(__dirname, "..", "data", "agentpi.db"));
  const bus = new DaemonEventBus();
  const runtimeUpdater = new PiRuntimeUpdater();
  const rpcPool = new RpcProcessPool();
  const searchIndexer = new SearchIndexer(store);
  const stats = new StatsAggregator();
  const sessions = new SessionManager(runtimeUpdater, rpcPool, bus, store, searchIndexer, stats);
  const worktree = new WorktreeService();
  const workflows = new WorkflowEngine(store, sessions, bus);
  const devServers = new DevServerService();
  const terminals = new TerminalService(bus);

  const writeAuditLog = (
    req: express.Request,
    action: string,
    params: Record<string, unknown>,
    result: "ok" | "rejected" | "error",
  ): void => {
    const actor = req.header("x-agentpi-actor") ?? "local-client";
    store.insertAuditLog({
      actor,
      action,
      paramsJson: JSON.stringify(params),
      result,
      createdAt: new Date().toISOString(),
    });
  };

  app.get("/health", (_req, res) => {
    res.json({ ok: true, now: new Date().toISOString() });
  });

  app.use((req, res, next) => {
    if (req.path === "/health") {
      next();
      return;
    }
    if (!isAllowedOrigin(req.header("origin"))) {
      writeAuditLog(req, "request.denied.origin", { path: req.path, origin: req.header("origin") }, "rejected");
      res.status(403).json({ error: "Origin not allowed" });
      return;
    }
    const token = extractHttpToken(req);
    if (!token || token !== daemonToken) {
      writeAuditLog(req, "request.denied.auth", { path: req.path }, "rejected");
      res.status(401).json({ error: "Unauthorized" });
      return;
    }
    next();
  });

  app.get("/health/details", (_req, res) => {
    res.status(200).json({
      ok: true,
      now: new Date().toISOString(),
      daemon: {
        startedAt,
        pid: process.pid,
        nodeVersion: process.version,
        platform: process.platform,
        uptimeSec: Math.floor(process.uptime()),
      },
      auth: {
        mode: "local-token",
        tokenRequired: true,
      },
      ws: {
        currentConnections: wsCurrentConnections,
        acceptedConnections: wsAcceptedConnections,
        rejectedConnections: wsRejectedConnections,
      },
      http: {
        port: boundPort,
      },
    });
  });

  app.post("/v1/sessions", async (req, res) => {
    try {
      const input = parseOrThrow(CreateSessionRequestSchema, req.body);
      const created = await sessions.createSession(input);
      res.status(201).json(created);
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/sessions/:id/prompt", async (req, res) => {
    try {
      const input = parseOrThrow(SessionPromptRequestSchema, req.body);
      await sessions.prompt(req.params.id, input);
      res.status(202).json({ ok: true });
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/sessions/:id/steer", async (req, res) => {
    try {
      const input = parseOrThrow(SessionPromptRequestSchema, req.body);
      await sessions.steer(req.params.id, input);
      res.status(202).json({ ok: true });
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/sessions/:id/follow-up", async (req, res) => {
    try {
      const input = parseOrThrow(SessionPromptRequestSchema, req.body);
      await sessions.followUp(req.params.id, input);
      res.status(202).json({ ok: true });
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/sessions/:id/abort", async (req, res) => {
    try {
      await sessions.abort(req.params.id);
      res.status(200).json({ ok: true });
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.get("/v1/sessions/:id/state", async (req, res) => {
    try {
      const state = await sessions.getState(req.params.id);
      res.status(200).json({ sessionId: req.params.id, state });
    } catch (error) {
      res.status(404).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.get("/v1/sessions/:id/runtime-state", async (req, res) => {
    try {
      const runtimeState = await sessions.getRuntimeState(req.params.id, true);
      res.status(200).json({ sessionId: req.params.id, runtimeState });
    } catch (error) {
      res.status(404).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/sessions/:id/wait-idle", async (req, res) => {
    try {
      const input = parseOrThrow(WaitSessionIdleRequestSchema, req.body ?? {});
      const runtimeState = await sessions.waitIdle(req.params.id, input.timeoutMs);
      res.status(200).json({ sessionId: req.params.id, runtimeState });
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/worktrees", async (req, res) => {
    try {
      const input = parseOrThrow(CreateWorktreeRequestSchema, req.body);
      const repoPath = asSafeDirectory(input.repoPath);
      if (!/^[\w./-]+$/.test(input.branchName)) {
        throw new Error("Invalid branchName");
      }
      if (!/^[\w.-]+$/.test(input.directoryName)) {
        throw new Error("Invalid directoryName");
      }
      const created = await worktree.createWorktree({
        ...input,
        repoPath,
      });
      writeAuditLog(req, "worktree.create", { repoPath, branchName: input.branchName, directoryName: input.directoryName }, "ok");
      res.status(201).json(created);
    } catch (error) {
      writeAuditLog(req, "worktree.create", { body: req.body }, "error");
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.delete("/v1/worktrees/:id", async (req, res) => {
    try {
      const worktreePath = worktree.decodeWorktreeId(req.params.id);
      await worktree.removeWorktree(worktreePath);
      writeAuditLog(req, "worktree.remove", { worktreePath }, "ok");
      res.status(200).json({ ok: true });
    } catch (error) {
      writeAuditLog(req, "worktree.remove", { worktreeId: req.params.id }, "error");
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/workflows", (req, res) => {
    try {
      const input = parseOrThrow(CreateWorkflowRequestSchema, req.body);
      const workflowId = workflows.createWorkflow(input.graph);
      res.status(201).json({ workflowId });
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/workflows/:id/run", async (req, res) => {
    try {
      const input = parseOrThrow(RunWorkflowRequestSchema, req.body);
      const state = await workflows.runWorkflow(req.params.id, input);
      res.status(202).json({ runId: state.id, state });
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.get("/v1/workflows/runs/:runId", (req, res) => {
    try {
      const state = workflows.getRunState(req.params.runId);
      res.status(200).json({ runId: req.params.runId, state });
    } catch (error) {
      res.status(404).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/workflows/:id/validate", (req, res) => {
    try {
      const result = workflows.validateWorkflow(req.params.id);
      res.status(200).json(result);
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/approvals/:id/decision", (req, res) => {
    try {
      const input = parseOrThrow(ApprovalDecisionInputSchema, req.body ?? {});
      workflows.resolveApproval({
        id: randomUUID(),
        requestId: req.params.id,
        decision: input.decision,
        actor: input.actor,
        comment: input.comment,
        decidedAt: new Date().toISOString(),
      });
      res.status(200).json({ ok: true });
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/runtime/update/check", async (req, res) => {
    try {
      const input = parseOrThrow(CheckRuntimeUpdateRequestSchema, req.body ?? {});
      const result = await runtimeUpdater.checkForUpdate(input.channel);
      res.status(200).json(result);
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/runtime/update/apply", async (req, res) => {
    try {
      const input = parseOrThrow(ApplyRuntimeUpdateRequestSchema, req.body ?? {});
      const result = await runtimeUpdater.applyUpdate(input.channel, input.targetVersion, (progress) => {
        bus.emitWs({
          type: "runtime.update.state",
          channel: input.channel,
          state: progress,
        });
      }, input.promoteToStable);
      res.status(200).json(result);
    } catch (error) {
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.get("/v1/search", (req, res) => {
    const q = String(req.query.q ?? "");
    const limit = Number(req.query.limit ?? 50);
    const data = searchIndexer.search(q, Number.isFinite(limit) ? limit : 50);
    res.status(200).json({ query: q, results: data });
  });

  app.get("/v1/stats/:id", (req, res) => {
    const data = stats.getSessionStats(req.params.id);
    res.status(200).json(data);
  });

  app.post("/v1/terminals", (req, res) => {
    try {
      const cwd = asSafeDirectory(typeof req.body?.cwd === "string" ? req.body.cwd : process.cwd());
      const shell = validateShell(typeof req.body?.shell === "string" ? req.body.shell : undefined);
      const terminalId = terminals.start(cwd, shell);
      writeAuditLog(req, "terminal.start", { cwd, shell }, "ok");
      res.status(201).json({ terminalId });
    } catch (error) {
      writeAuditLog(req, "terminal.start", { body: req.body }, "error");
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.post("/v1/terminals/:id/input", (req, res) => {
    try {
      const input = String(req.body?.input ?? "");
      if (input.length > 8_192) {
        throw new Error("terminal input too large");
      }
      terminals.write(req.params.id, input);
      writeAuditLog(req, "terminal.input", { terminalId: req.params.id, bytes: input.length }, "ok");
      res.status(200).json({ ok: true });
    } catch (error) {
      writeAuditLog(req, "terminal.input", { terminalId: req.params.id }, "error");
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.delete("/v1/terminals/:id", (req, res) => {
    terminals.stop(req.params.id);
    writeAuditLog(req, "terminal.stop", { terminalId: req.params.id }, "ok");
    res.status(200).json({ ok: true });
  });

  app.post("/v1/dev-servers", (req, res) => {
    try {
      const command = String(req.body?.command ?? "npm");
      const args = Array.isArray(req.body?.args) ? req.body.args.map(String) : ["run", "dev"];
      const cwd = asSafeDirectory(String(req.body?.cwd ?? process.cwd()));
      const validated = validateCommand(command, args);
      const id = devServers.start(validated.command, validated.args, cwd);
      writeAuditLog(req, "devserver.start", { command: validated.command, args: validated.args, cwd }, "ok");
      res.status(201).json({ devServerId: id });
    } catch (error) {
      writeAuditLog(req, "devserver.start", { body: req.body }, "error");
      res.status(400).json({ error: error instanceof Error ? error.message : String(error) });
    }
  });

  app.delete("/v1/dev-servers/:id", (req, res) => {
    devServers.stop(req.params.id);
    writeAuditLog(req, "devserver.stop", { devServerId: req.params.id }, "ok");
    res.status(200).json({ ok: true });
  });

  const server = createServer(app);
  const wss = new WebSocketServer({ server, path: "/ws" });
  const baseShouldHandle = wss.shouldHandle.bind(wss);
  wss.shouldHandle = (request) => {
    if (!baseShouldHandle(request)) return false;
    const origin = request.headers.origin;
    const token = extractWsToken(request.url, request.headers);
    const allowed = isAllowedOrigin(origin) && token === daemonToken;
    if (!allowed) {
      wsRejectedConnections += 1;
    }
    return allowed;
  };
  wss.on("connection", (client) => {
    wsCurrentConnections += 1;
    wsAcceptedConnections += 1;
    client.on("close", () => {
      wsCurrentConnections = Math.max(0, wsCurrentConnections - 1);
    });
  });

  const unsubscribe = bus.onWs((event) => {
    const payload = JSON.stringify(event);
    for (const client of wss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(payload);
      }
    }
  });

  async function listen(port = Number(process.env.AGENTPI_DAEMON_PORT ?? 43210)): Promise<{ port: number }> {
    await new Promise<void>((resolve) => {
      server.listen(port, () => resolve());
    });
    const address = server.address();
    if (address && typeof address === "object") {
      boundPort = address.port;
    } else {
      boundPort = port;
    }
    log("info", "agentpi daemon listening", { port: boundPort });
    return { port: boundPort };
  }

  async function shutdown(): Promise<void> {
    unsubscribe();
    devServers.stopAll();
    await rpcPool.closeAll();
    await new Promise<void>((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
  }

  return {
    listen,
    shutdown,
  };
}
