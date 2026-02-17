import { describe, expect, it } from "vitest";
import type { WorkflowGraphV1 } from "@agentpi/protocol";
import { WorkflowCompiler } from "./WorkflowCompiler.js";

describe("WorkflowCompiler", () => {
  it("compiles a valid graph", () => {
    const graph: WorkflowGraphV1 = {
      version: 1,
      name: "compile-demo",
      nodes: [
        { id: "start", type: "start", label: "Start", config: {} },
        { id: "prompt", type: "prompt", label: "Prompt", config: { prompt: "hello" } },
        { id: "end", type: "end", label: "End", config: { success: true } },
      ],
      edges: [
        { id: "e1", source: "start", target: "prompt" },
        { id: "e2", source: "prompt", target: "end" },
      ],
    };

    const compiler = new WorkflowCompiler();
    const compiled = compiler.compile(graph);

    expect(compiled.startNodeId).toBe("start");
    expect(compiled.nodesById.size).toBe(3);
  });

  it("throws on unknown edge target", () => {
    const graph: WorkflowGraphV1 = {
      version: 1,
      name: "bad-graph",
      nodes: [{ id: "start", type: "start", label: "Start", config: {} }],
      edges: [{ id: "e1", source: "start", target: "missing" }],
    };

    const compiler = new WorkflowCompiler();
    expect(() => compiler.compile(graph)).toThrow(/unknown target/);
  });
});
