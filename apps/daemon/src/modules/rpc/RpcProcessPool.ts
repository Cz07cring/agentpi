import type { RuntimeChannel } from "@agentpi/protocol";
import { log } from "../../lib/logger.js";
import type { ResolvedRuntime } from "../runtime/types.js";
import { RpcClientProcess } from "./RpcClientProcess.js";

export interface SessionRpcBinding {
  sessionId: string;
  channel: RuntimeChannel;
  runtime: ResolvedRuntime;
  cwd: string;
  provider?: string;
  model?: string;
}

export class RpcProcessPool {
  private readonly sessions = new Map<string, RpcClientProcess>();

  async create(binding: SessionRpcBinding): Promise<RpcClientProcess> {
    if (this.sessions.has(binding.sessionId)) {
      throw new Error(`RPC process for session ${binding.sessionId} already exists`);
    }

    const client = new RpcClientProcess({
      runtime: binding.runtime,
      cwd: binding.cwd,
      platformSessionId: binding.sessionId,
      provider: binding.provider,
      model: binding.model,
    });

    client.on("stderr", (chunk) => {
      log("warn", "rpc stderr", { sessionId: binding.sessionId, chunk: String(chunk).trim() });
    });

    client.on("close", ({ code, signal }) => {
      log("warn", "rpc process closed", { sessionId: binding.sessionId, code, signal });
      this.sessions.delete(binding.sessionId);
    });

    await client.start();
    this.sessions.set(binding.sessionId, client);
    return client;
  }

  get(sessionId: string): RpcClientProcess {
    const session = this.sessions.get(sessionId);
    if (!session) throw new Error(`Session ${sessionId} is not active`);
    return session;
  }

  async close(sessionId: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) return;
    await session.stop();
    this.sessions.delete(sessionId);
  }

  async closeAll(): Promise<void> {
    await Promise.all(Array.from(this.sessions.keys()).map((id) => this.close(id)));
  }
}
