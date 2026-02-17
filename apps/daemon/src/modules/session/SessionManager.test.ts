import { EventEmitter } from "node:events";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it, vi } from "vitest";
import { DaemonEventBus } from "../../lib/event-bus.js";
import type { RpcClientProcess } from "../rpc/RpcClientProcess.js";
import type { RpcProcessPool } from "../rpc/RpcProcessPool.js";
import type { PiRuntimeUpdater } from "../runtime/PiRuntimeUpdater.js";
import { SearchIndexer } from "../search/SearchIndexer.js";
import { SessionManager } from "./SessionManager.js";
import { PersistenceStore } from "../storage/PersistenceStore.js";
import type { StatsAggregator } from "../stats/StatsAggregator.js";

class FakeRpcClient extends EventEmitter {
  private runtimeState: Record<string, unknown> = {
    sessionId: "runtime-session-1",
    isStreaming: false,
    messageCount: 0,
  };

  async send(command: string): Promise<unknown> {
    if (command === "get_state") {
      return this.runtimeState;
    }
    if (command === "prompt") {
      this.runtimeState = { ...this.runtimeState, isStreaming: true };
      setTimeout(() => {
        this.runtimeState = { ...this.runtimeState, isStreaming: false };
        this.emit("event", { type: "agent_end" });
      }, 40);
      return { ok: true };
    }
    return { ok: true };
  }
}

function createStore(): PersistenceStore {
  const dir = mkdtempSync(join(tmpdir(), "agentpi-session-test-"));
  return new PersistenceStore(join(dir, "agentpi.db"));
}

describe("SessionManager", () => {
  it("tracks platform->runtime session state and supports waitIdle", async () => {
    const store = createStore();
    const bus = new DaemonEventBus();
    const rpc = new FakeRpcClient();
    const runtimeUpdater = {
      selectRuntimeForNewSession: vi.fn(async () => ({
        version: "0.52.12",
        channel: "stable",
        rootDir: "/tmp/runtime",
        cliPath: "/tmp/runtime/cli.js",
      })),
    } as unknown as PiRuntimeUpdater;
    const rpcPool = {
      create: vi.fn(async () => rpc as unknown as RpcClientProcess),
      close: vi.fn(async () => {}),
      closeAll: vi.fn(async () => {}),
    } as unknown as RpcProcessPool;
    const searchIndexer = new SearchIndexer(store);
    const stats = {
      onSessionEvent: vi.fn(),
    } as unknown as StatsAggregator;

    const manager = new SessionManager(runtimeUpdater, rpcPool, bus, store, searchIndexer, stats);
    const created = await manager.createSession({
      runtimeChannel: "stable",
      cwd: process.cwd(),
    });

    const runtimeStateBefore = await manager.getRuntimeState(created.sessionId, true);
    expect(runtimeStateBefore.runtimeSessionId).toBe("runtime-session-1");
    expect(runtimeStateBefore.status).toBe("idle");

    await manager.prompt(created.sessionId, { message: "hello" });
    const idleState = await manager.waitIdle(created.sessionId, 1_500);
    expect(idleState.status).toBe("idle");
    expect(idleState.runtimeSessionId).toBe("runtime-session-1");
  });
});

