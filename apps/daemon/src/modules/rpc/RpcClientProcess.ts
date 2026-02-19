import { EventEmitter } from "node:events";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ResolvedRuntime } from "../runtime/types.js";

interface PendingRequest {
  resolve: (value: unknown) => void;
  reject: (error: Error) => void;
  timeout: NodeJS.Timeout;
}

export interface RpcClientProcessOptions {
  runtime: ResolvedRuntime;
  cwd: string;
  platformSessionId: string;
  provider?: string;
  model?: string;
}

const MAX_BUFFER_BYTES = 10 * 1024 * 1024; // 10 MB

export class RpcClientProcess extends EventEmitter {
  private child: ChildProcessWithoutNullStreams | null = null;
  private buffer = "";
  private requestCounter = 0;
  private pending = new Map<string, PendingRequest>();
  private readonly options: RpcClientProcessOptions;

  constructor(options: RpcClientProcessOptions) {
    super();
    this.options = options;
  }

  async start(): Promise<void> {
    if (this.child) return;

    const args = [this.options.runtime.cliPath, "--mode", "rpc"];
    if (this.options.provider) {
      args.push("--provider", this.options.provider);
    }
    if (this.options.model) {
      args.push("--model", this.options.model);
    }

    const sessionDir = join(homedir(), ".agentpi", "sessions", this.options.platformSessionId);
    mkdirSync(sessionDir, { recursive: true });

    const env = { ...process.env } as NodeJS.ProcessEnv;
    delete env.AGENTPI_DAEMON_TOKEN;

    this.child = spawn(process.execPath, args, {
      cwd: this.options.cwd,
      stdio: "pipe",
      env: {
        ...env,
        AGENTPI_SESSION_DIR: sessionDir,
        PI_SESSION_DIR: sessionDir,
      },
    });

    this.child.stdout.setEncoding("utf8");
    this.child.stdout.on("data", (chunk: string) => this.onStdout(chunk));

    this.child.stderr.setEncoding("utf8");
    this.child.stderr.on("data", (chunk: string) => {
      this.emit("stderr", chunk);
    });

    this.child.on("error", (error) => {
      this.emit("error", error);
    });

    this.child.on("close", (code, signal) => {
      this.emit("close", { code, signal });
      this.rejectAllPending(new Error(`rpc process closed code=${String(code)} signal=${String(signal)}`));
      this.child = null;
    });

    await this.waitForSpawnReady();
  }

  private async waitForSpawnReady(): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      if (!this.child) {
        reject(new Error("RPC process not started"));
        return;
      }

      const spawnTimeoutMs = Number(process.env.AGENTPI_RPC_SPAWN_TIMEOUT_MS) || 15_000;
      const timeout = setTimeout(() => {
        reject(new Error("RPC process did not become ready in time"));
      }, spawnTimeoutMs);

      const onError = (error: Error) => {
        clearTimeout(timeout);
        this.off("error", onError);
        reject(error);
      };

      this.on("error", onError);

      this.send("get_state", undefined, spawnTimeoutMs)
        .then(() => {
          clearTimeout(timeout);
          this.off("error", onError);
          resolve();
        })
        .catch((error) => {
          clearTimeout(timeout);
          this.off("error", onError);
          reject(error);
        });
    });
  }

  async stop(): Promise<void> {
    if (!this.child) return;

    this.child.kill("SIGTERM");
    await new Promise<void>((resolve) => {
      const timeout = setTimeout(() => {
        this.child?.kill("SIGKILL");
        resolve();
      }, 1500);

      this.child?.once("close", () => {
        clearTimeout(timeout);
        resolve();
      });
    });
  }

  async send(command: string, payload?: Record<string, unknown>, timeoutMs = 60_000): Promise<unknown> {
    const child = this.child;
    if (!child) throw new Error("RPC process is not running");

    const id = `rpc-${++this.requestCounter}`;
    const envelope = {
      id,
      type: command,
      ...(payload ?? {}),
    };

    return await new Promise<unknown>((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`RPC command timeout: ${command}`));
      }, timeoutMs);

      this.pending.set(id, { resolve, reject, timeout });
      child.stdin.write(JSON.stringify(envelope) + "\n");
    });
  }

  private onStdout(chunk: string): void {
    this.buffer += chunk;
    if (this.buffer.length > MAX_BUFFER_BYTES) {
      this.emit("error", new Error("RPC stdout buffer exceeded 10 MB without a newline"));
      this.buffer = "";
      return;
    }
    while (true) {
      const newlineIndex = this.buffer.indexOf("\n");
      if (newlineIndex < 0) break;
      const line = this.buffer.slice(0, newlineIndex).trim();
      this.buffer = this.buffer.slice(newlineIndex + 1);
      if (!line) continue;

      let parsed: Record<string, unknown>;
      try {
        parsed = JSON.parse(line) as Record<string, unknown>;
      } catch {
        this.emit("unparsed_line", line);
        continue;
      }

      if (parsed.type === "response" && typeof parsed.id === "string") {
        const pending = this.pending.get(parsed.id);
        if (!pending) continue;
        clearTimeout(pending.timeout);
        this.pending.delete(parsed.id);

        if (parsed.success === false) {
          pending.reject(new Error(String(parsed.error ?? `RPC ${String(parsed.command)} failed`)));
        } else {
          pending.resolve(parsed.data ?? parsed);
        }
        continue;
      }

      this.emit("event", parsed);
    }
  }

  private rejectAllPending(error: Error): void {
    for (const [id, pending] of this.pending) {
      clearTimeout(pending.timeout);
      pending.reject(error);
      this.pending.delete(id);
    }
  }
}
