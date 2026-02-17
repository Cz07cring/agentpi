import { randomUUID } from "node:crypto";
import type {
  CreateSessionRequest,
  CreateSessionResponse,
  RuntimeChannel,
  SessionRuntimeState,
  SessionPromptRequest,
  SessionRuntimeBinding,
} from "@agentpi/protocol";
import { log } from "../../lib/logger.js";
import type { DaemonEventBus } from "../../lib/event-bus.js";
import type { SearchIndexer } from "../search/SearchIndexer.js";
import type { PersistenceStore } from "../storage/PersistenceStore.js";
import type { StatsAggregator } from "../stats/StatsAggregator.js";
import type { RpcClientProcess } from "../rpc/RpcClientProcess.js";
import { RpcProcessPool } from "../rpc/RpcProcessPool.js";
import { PiRuntimeUpdater } from "../runtime/PiRuntimeUpdater.js";

interface ManagedSession {
  id: string;
  cwd: string;
  channel: RuntimeChannel;
  binding: SessionRuntimeBinding;
  rpc: RpcClientProcess;
  state: Record<string, unknown>;
  runtimeState: SessionRuntimeState;
}

const START_EVENT_TYPES = new Set(["agent_start", "turn_start", "message_start", "tool_execution_start"]);
const END_EVENT_TYPES = new Set(["agent_end", "turn_end", "abort_end", "error"]);

function messageToPlainText(message: unknown): string {
  if (!message || typeof message !== "object") return "";
  const msg = message as Record<string, unknown>;
  const content = msg.content;

  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";

  return content
    .map((part) => {
      if (!part || typeof part !== "object") return "";
      const block = part as Record<string, unknown>;
      if (block.type === "text") return String(block.text ?? "");
      if (block.type === "thinking") return String(block.thinking ?? "");
      if (block.type === "toolCall") return `tool:${String(block.name ?? "unknown")}`;
      return "";
    })
    .filter(Boolean)
    .join("\n");
}

export class SessionManager {
  private readonly sessions = new Map<string, ManagedSession>();

  constructor(
    private readonly runtimeUpdater: PiRuntimeUpdater,
    private readonly rpcPool: RpcProcessPool,
    private readonly bus: DaemonEventBus,
    private readonly store: PersistenceStore,
    private readonly searchIndexer: SearchIndexer,
    private readonly stats: StatsAggregator,
  ) {}

  async createSession(request: CreateSessionRequest): Promise<CreateSessionResponse> {
    const sessionId = randomUUID();
    const channel = request.runtimeChannel ?? "stable";
    const runtime = await this.runtimeUpdater.selectRuntimeForNewSession(channel, sessionId);

    const binding: SessionRuntimeBinding = {
      sessionId,
      runtimeVersion: runtime.version,
      channel,
      pinned: true,
      createdAt: new Date().toISOString(),
    };

    const cwd = request.cwd ?? process.cwd();

    const rpc = await this.rpcPool.create({
      sessionId,
      channel,
      runtime,
      cwd,
      provider: request.provider,
      model: request.model,
    });

    const managed: ManagedSession = {
      id: sessionId,
      cwd,
      channel,
      binding,
      rpc,
      state: {},
      runtimeState: {
        sessionId,
        runtimeVersion: binding.runtimeVersion,
        runtimeSessionId: undefined,
        status: "unknown",
        isStreaming: false,
      },
    };

    this.sessions.set(sessionId, managed);

    rpc.on("event", (event: Record<string, unknown>) => {
      this.onRpcEvent(sessionId, event);
    });

    this.persistSessionState(managed, {});
    this.persistRuntimeState(managed);

    await this.getState(sessionId);

    return {
      sessionId,
      binding,
    };
  }

  async prompt(sessionId: string, input: SessionPromptRequest): Promise<void> {
    const session = this.get(sessionId);
    this.markSessionRunning(session);
    await session.rpc.send("prompt", {
      message: input.message,
      images: input.images,
      streamingBehavior: input.streamingBehavior,
    });
  }

  async steer(sessionId: string, input: SessionPromptRequest): Promise<void> {
    const session = this.get(sessionId);
    this.markSessionRunning(session);
    await session.rpc.send("steer", {
      message: input.message,
      images: input.images,
    });
  }

  async followUp(sessionId: string, input: SessionPromptRequest): Promise<void> {
    const session = this.get(sessionId);
    this.markSessionRunning(session);
    await session.rpc.send("follow_up", {
      message: input.message,
      images: input.images,
    });
  }

  async abort(sessionId: string): Promise<void> {
    const session = this.get(sessionId);
    await session.rpc.send("abort");
    session.runtimeState = {
      ...session.runtimeState,
      status: "idle",
      isStreaming: false,
      lastEventAt: new Date().toISOString(),
    };
    this.persistRuntimeState(session);
  }

  async getState(sessionId: string): Promise<Record<string, unknown>> {
    const session = this.get(sessionId);
    const state = (await session.rpc.send("get_state")) as Record<string, unknown>;
    session.state = state;
    this.refreshRuntimeStateFromSnapshot(session, state);
    this.persistSessionState(session, state);
    this.persistRuntimeState(session);

    this.bus.emitWs({
      type: "session.state",
      sessionId,
      state,
    });

    return state;
  }

  async getRuntimeState(sessionId: string, refresh = false): Promise<SessionRuntimeState> {
    const active = this.sessions.get(sessionId);
    if (active) {
      if (refresh) {
        await this.getState(sessionId);
      }
      return { ...active.runtimeState };
    }

    const persisted = this.store.getSessionRuntimeBinding(sessionId);
    if (!persisted) {
      throw new Error(`Session ${sessionId} not found`);
    }
    return {
      sessionId: persisted.sessionId,
      runtimeSessionId: persisted.runtimeSessionId ?? undefined,
      runtimeVersion: persisted.runtimeVersion,
      status: (persisted.status as SessionRuntimeState["status"]) ?? "unknown",
      isStreaming: persisted.isStreaming,
      lastEventAt: persisted.lastEventAt ?? undefined,
    };
  }

  async waitIdle(sessionId: string, timeoutMs = 60_000): Promise<SessionRuntimeState> {
    const deadline = Date.now() + timeoutMs;

    while (Date.now() <= deadline) {
      const runtimeState = await this.getRuntimeState(sessionId, true);
      if (!runtimeState.isStreaming) {
        return runtimeState;
      }

      const sleepMs = Math.min(250, Math.max(10, deadline - Date.now()));
      await new Promise<void>((resolve) => setTimeout(resolve, sleepMs));
    }

    throw new Error(`Session ${sessionId} did not become idle within ${timeoutMs}ms`);
  }

  async close(sessionId: string): Promise<void> {
    const session = this.get(sessionId);
    await this.rpcPool.close(sessionId);
    session.runtimeState = {
      ...session.runtimeState,
      status: "closed",
      isStreaming: false,
      lastEventAt: new Date().toISOString(),
    };
    this.persistRuntimeState(session);
    this.sessions.delete(sessionId);
  }

  listSessionIds(): string[] {
    return Array.from(this.sessions.keys());
  }

  private get(sessionId: string): ManagedSession {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }
    return session;
  }

  private onRpcEvent(sessionId: string, event: Record<string, unknown>): void {
    const session = this.get(sessionId);
    const eventType = String(event.type ?? "");
    const now = new Date().toISOString();

    if (START_EVENT_TYPES.has(eventType)) {
      session.runtimeState = {
        ...session.runtimeState,
        status: "running",
        isStreaming: true,
        lastEventAt: now,
      };
      this.persistRuntimeState(session);
    } else if (END_EVENT_TYPES.has(eventType)) {
      session.runtimeState = {
        ...session.runtimeState,
        status: "idle",
        isStreaming: false,
        lastEventAt: now,
      };
      this.persistRuntimeState(session);
    } else {
      session.runtimeState = {
        ...session.runtimeState,
        lastEventAt: now,
      };
      this.persistRuntimeState(session);
    }

    this.bus.emitWs({
      type: "session.event",
      sessionId,
      event,
    });

    this.stats.onSessionEvent(sessionId, event);

    if (eventType === "message_end" || eventType === "turn_end") {
      const messageText = messageToPlainText((event.message as unknown) ?? (event as unknown));
      if (messageText) {
        this.searchIndexer.indexSessionText(sessionId, messageText);
      }
    }

    if (eventType === "agent_end" || eventType === "turn_end") {
      this.getState(sessionId).catch((error) => {
        log("warn", "failed to refresh state after event", {
          sessionId,
          error: error instanceof Error ? error.message : String(error),
        });
      });
    }
  }

  private markSessionRunning(session: ManagedSession): void {
    session.runtimeState = {
      ...session.runtimeState,
      status: "running",
      isStreaming: true,
      lastEventAt: new Date().toISOString(),
    };
    this.persistRuntimeState(session);
  }

  private refreshRuntimeStateFromSnapshot(session: ManagedSession, state: Record<string, unknown>): void {
    const runtimeSessionId =
      typeof state.sessionId === "string" && state.sessionId.trim().length > 0
        ? state.sessionId
        : session.runtimeState.runtimeSessionId;
    const isStreaming = Boolean(state.isStreaming);

    session.runtimeState = {
      ...session.runtimeState,
      runtimeSessionId,
      isStreaming,
      status: isStreaming ? "running" : "idle",
      lastEventAt: new Date().toISOString(),
    };
  }

  private persistSessionState(session: ManagedSession, state: Record<string, unknown>): void {
    this.store.upsertSession({
      id: session.id,
      cwd: session.cwd,
      runtimeVersion: session.binding.runtimeVersion,
      runtimeChannel: session.binding.channel,
      createdAt: session.binding.createdAt,
      lastStateJson: JSON.stringify(state),
    });
  }

  private persistRuntimeState(session: ManagedSession): void {
    this.store.upsertSessionRuntimeBinding({
      sessionId: session.id,
      runtimeSessionId: session.runtimeState.runtimeSessionId ?? null,
      runtimeVersion: session.binding.runtimeVersion,
      status: session.runtimeState.status,
      isStreaming: session.runtimeState.isStreaming,
      lastEventAt: session.runtimeState.lastEventAt ?? null,
      updatedAt: new Date().toISOString(),
    });
  }
}
