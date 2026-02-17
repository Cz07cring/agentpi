import { describe, expect, it } from "vitest";
import {
  CreateSessionRequestSchema,
  SessionRuntimeStateSchema,
  WaitSessionIdleRequestSchema,
  WorkflowGraphV1Schema,
  WsEventSchema,
  parseOrThrow,
} from "./index.js";

describe("protocol schemas", () => {
  it("validates create session request", () => {
    const parsed = parseOrThrow(CreateSessionRequestSchema, { cwd: "/tmp/work", runtimeChannel: "stable" });
    expect(parsed.cwd).toBe("/tmp/work");
  });

  it("validates workflow graph", () => {
    const graph = parseOrThrow(WorkflowGraphV1Schema, {
      version: 1,
      name: "demo",
      nodes: [
        { id: "n1", type: "start", label: "Start", config: {} },
        { id: "n2", type: "prompt", label: "Prompt", config: { prompt: "hello" } },
        { id: "n3", type: "end", label: "End", config: { success: true } },
      ],
      edges: [
        { id: "e1", source: "n1", target: "n2" },
        { id: "e2", source: "n2", target: "n3" },
      ],
    });

    expect(graph.nodes).toHaveLength(3);
  });

  it("validates ws events", () => {
    const event = parseOrThrow(WsEventSchema, {
      type: "session.event",
      sessionId: "9a77c806-83b6-4634-8df1-637f84c0c744",
      event: { type: "message_update" },
    });

    expect(event.type).toBe("session.event");
  });

  it("validates runtime state and wait-idle request", () => {
    const runtimeState = parseOrThrow(SessionRuntimeStateSchema, {
      sessionId: "9a77c806-83b6-4634-8df1-637f84c0c744",
      runtimeSessionId: "runtime-1",
      runtimeVersion: "0.52.12",
      status: "running",
      isStreaming: true,
    });
    expect(runtimeState.status).toBe("running");

    const waitInput = parseOrThrow(WaitSessionIdleRequestSchema, { timeoutMs: 1500 });
    expect(waitInput.timeoutMs).toBe(1500);
  });

  it("validates approval ws events", () => {
    const event = parseOrThrow(WsEventSchema, {
      type: "approval.requested",
      runId: "9a77c806-83b6-4634-8df1-637f84c0c744",
      request: {
        id: "51995f42-4272-47ce-a0a0-21b9918f71e4",
        sessionId: "da3f6a7d-5949-4f97-8878-9093b02d57d1",
        toolName: "workflow",
        args: { nodeId: "approval-1" },
        status: "pending",
        sourceNodeId: "approval-1",
        blocking: true,
        createdAt: new Date().toISOString(),
      },
    });

    expect(event.type).toBe("approval.requested");
  });
});
