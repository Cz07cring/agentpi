import { randomUUID } from "node:crypto";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it, vi } from "vitest";
import type { ApprovalDecision, WorkflowGraphV1 } from "@agentpi/protocol";
import { DaemonEventBus } from "../../lib/event-bus.js";
import { PersistenceStore } from "../storage/PersistenceStore.js";
import type { SessionManager } from "../session/SessionManager.js";
import { WorkflowEngine } from "./WorkflowEngine.js";

function createStore(): PersistenceStore {
  const dir = mkdtempSync(join(tmpdir(), "agentpi-workflow-test-"));
  return new PersistenceStore(join(dir, "agentpi.db"));
}

async function waitFor(predicate: () => boolean, timeoutMs = 2_000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await new Promise<void>((resolve) => setTimeout(resolve, 25));
  }
  throw new Error("Timed out waiting for condition");
}

describe("WorkflowEngine", () => {
  it("waits for session idle on prompt nodes by default", async () => {
    const store = createStore();
    const bus = new DaemonEventBus();
    const sessions = {
      createSession: vi.fn(async () => ({ sessionId: randomUUID(), binding: {} })),
      prompt: vi.fn(async () => {}),
      waitIdle: vi.fn(async () => ({
        sessionId: "af037428-b4c5-4043-a61e-5b78e5aa7086",
        runtimeVersion: "0.52.12",
        status: "idle",
        isStreaming: false,
      })),
    } as unknown as SessionManager;

    const engine = new WorkflowEngine(store, sessions, bus);
    const workflowId = engine.createWorkflow({
      version: 1,
      name: "prompt-wait",
      nodes: [
        { id: "start", type: "start", label: "Start", config: {} },
        { id: "prompt", type: "prompt", label: "Prompt", config: { prompt: "hello" } },
        { id: "end", type: "end", label: "End", config: { success: true } },
      ],
      edges: [
        { id: "e1", source: "start", target: "prompt" },
        { id: "e2", source: "prompt", target: "end" },
      ],
    } satisfies WorkflowGraphV1);

    const state = await engine.runWorkflow(workflowId, {
      sessionId: "af037428-b4c5-4043-a61e-5b78e5aa7086",
    });

    expect(sessions.prompt).toHaveBeenCalledTimes(1);
    expect(sessions.waitIdle).toHaveBeenCalledTimes(1);
    expect(state.status).toBe("completed");
  });

  it("enters waiting_approval and resumes after decision", async () => {
    const store = createStore();
    const bus = new DaemonEventBus();
    const sessions = {
      createSession: vi.fn(async () => ({ sessionId: randomUUID(), binding: {} })),
      prompt: vi.fn(async () => {}),
      waitIdle: vi.fn(async () => ({
        sessionId: "af037428-b4c5-4043-a61e-5b78e5aa7086",
        runtimeVersion: "0.52.12",
        status: "idle",
        isStreaming: false,
      })),
    } as unknown as SessionManager;

    const engine = new WorkflowEngine(store, sessions, bus);
    const workflowId = engine.createWorkflow({
      version: 1,
      name: "approval-blocking",
      nodes: [
        { id: "start", type: "start", label: "Start", config: {} },
        { id: "approval", type: "approval", label: "Approval", config: { policy: "always", blocking: true } },
        { id: "end", type: "end", label: "End", config: { success: true } },
      ],
      edges: [
        { id: "e1", source: "start", target: "approval" },
        { id: "e2", source: "approval", target: "end" },
      ],
    } satisfies WorkflowGraphV1);

    let runId: string | null = null;
    bus.onWs((event) => {
      if (event.type === "workflow.run.state") {
        runId = event.runId;
      }
    });

    const pending = engine.runWorkflow(workflowId, {
      sessionId: "af037428-b4c5-4043-a61e-5b78e5aa7086",
    });

    await waitFor(() => runId !== null);
    await waitFor(() => {
      if (!runId) return false;
      return engine.getRunState(runId).status === "waiting_approval";
    });

    const waitingState = engine.getRunState(runId!);
    expect(waitingState.pendingApprovalId).toBeDefined();

    const decision: ApprovalDecision = {
      id: randomUUID(),
      requestId: waitingState.pendingApprovalId!,
      decision: "approved",
      actor: "tester",
      decidedAt: new Date().toISOString(),
    };
    engine.resolveApproval(decision);

    const finalState = await pending;
    expect(finalState.status).toBe("completed");
  });

  it("fails safely on invalid condition expressions", async () => {
    const store = createStore();
    const bus = new DaemonEventBus();
    const sessions = {
      createSession: vi.fn(async () => ({ sessionId: randomUUID(), binding: {} })),
      prompt: vi.fn(async () => {}),
      waitIdle: vi.fn(async () => ({
        sessionId: "af037428-b4c5-4043-a61e-5b78e5aa7086",
        runtimeVersion: "0.52.12",
        status: "idle",
        isStreaming: false,
      })),
    } as unknown as SessionManager;

    const engine = new WorkflowEngine(store, sessions, bus);
    const workflowId = engine.createWorkflow({
      version: 1,
      name: "unsafe-condition",
      nodes: [
        { id: "start", type: "start", label: "Start", config: {} },
        { id: "cond", type: "condition", label: "Condition", config: { expression: "process.exit()" } },
        { id: "end", type: "end", label: "End", config: { success: true } },
      ],
      edges: [
        { id: "e1", source: "start", target: "cond" },
        { id: "e2", source: "cond", target: "end", label: "true" },
      ],
    } satisfies WorkflowGraphV1);

    const state = await engine.runWorkflow(workflowId, {
      sessionId: "af037428-b4c5-4043-a61e-5b78e5aa7086",
    });
    expect(state.status).toBe("failed");
    expect(state.error).toMatch(/Condition evaluation failed/);
  });
});

