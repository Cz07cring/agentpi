import type { WorkflowEdge, WorkflowGraphV1, WorkflowNode } from "@agentpi/protocol";

export interface CompiledWorkflow {
  graph: WorkflowGraphV1;
  startNodeId: string;
  nodesById: Map<string, WorkflowNode>;
  outgoingEdges: Map<string, WorkflowEdge[]>;
}

export class WorkflowCompiler {
  compile(graph: WorkflowGraphV1): CompiledWorkflow {
    const nodesById = new Map<string, WorkflowNode>();

    for (const node of graph.nodes) {
      if (nodesById.has(node.id)) {
        throw new Error(`Duplicate workflow node id: ${node.id}`);
      }
      nodesById.set(node.id, node);
    }

    const outgoingEdges = new Map<string, WorkflowEdge[]>();
    for (const edge of graph.edges) {
      if (!nodesById.has(edge.source)) {
        throw new Error(`Edge ${edge.id} references unknown source ${edge.source}`);
      }
      if (!nodesById.has(edge.target)) {
        throw new Error(`Edge ${edge.id} references unknown target ${edge.target}`);
      }
      const list = outgoingEdges.get(edge.source) ?? [];
      list.push(edge);
      outgoingEdges.set(edge.source, list);
    }

    const starts = graph.nodes.filter((node) => node.type === "start");
    const startNode = starts[0] ?? graph.nodes[0];
    if (!startNode) {
      throw new Error("Workflow graph has no nodes");
    }

    return {
      graph,
      startNodeId: startNode.id,
      nodesById,
      outgoingEdges,
    };
  }
}
