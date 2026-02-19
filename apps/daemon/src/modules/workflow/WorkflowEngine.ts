import { randomUUID } from "node:crypto";
import type {
  ApprovalDecision,
  ApprovalRequest,
  CreateSessionRequest,
  SessionPromptRequest,
  ValidateWorkflowResponse,
  WorkflowGraphV1,
  WorkflowNode,
  WorkflowNodeResult,
  WorkflowRunState,
} from "@agentpi/protocol";
import type { DaemonEventBus } from "../../lib/event-bus.js";
import type { PersistenceStore } from "../storage/PersistenceStore.js";
import { WorkflowCompiler, type CompiledWorkflow } from "./WorkflowCompiler.js";
import type { SessionManager } from "../session/SessionManager.js";
import { evaluateSafeCondition } from "./SafeConditionEvaluator.js";

export interface WorkflowRunInput {
  sessionId?: string;
  input?: string;
}

interface WorkflowExecutionContext {
  sessionId: string;
  variables: Record<string, unknown>;
}

interface ApprovalWaiter {
  runId: string;
  timeout: NodeJS.Timeout;
  resolve: (request: ApprovalRequest) => void;
  reject: (error: Error) => void;
}

interface TaskResult {
  ok: boolean;
  error?: Error;
}

export class WorkflowEngine {
  private readonly compiler = new WorkflowCompiler();
  private readonly approvals = new Map<string, ApprovalRequest>();
  private readonly approvalWaiters = new Map<string, ApprovalWaiter>();
  private readonly runs = new Map<string, WorkflowRunState>();

  constructor(
    private readonly store: PersistenceStore,
    private readonly sessions: SessionManager,
    private readonly bus: DaemonEventBus,
  ) {}

  createWorkflow(graph: WorkflowGraphV1): string {
    this.compiler.compile(graph);
    const workflowId = randomUUID();
    this.store.insertWorkflow({
      id: workflowId,
      graphJson: JSON.stringify(graph),
      createdAt: new Date().toISOString(),
    });
    return workflowId;
  }

  validateWorkflow(workflowId: string): ValidateWorkflowResponse {
    const stored = this.store.getWorkflow(workflowId);
    if (!stored) {
      throw new Error(`Workflow ${workflowId} not found`);
    }

    const errors: string[] = [];
    const warnings: string[] = [];

    let compiled: CompiledWorkflow | null = null;
    try {
      const graph = JSON.parse(stored.graphJson) as WorkflowGraphV1;
      compiled = this.compiler.compile(graph);
      this.validateGraphFeasibility(compiled, errors, warnings);
    } catch (error) {
      errors.push(error instanceof Error ? error.message : String(error));
    }

    return {
      workflowId,
      valid: compiled !== null && errors.length === 0,
      errors,
      warnings,
    };
  }

  getRunState(runId: string): WorkflowRunState {
    const inMemory = this.runs.get(runId);
    if (inMemory) {
      return {
        ...inMemory,
        nodeResults: inMemory.nodeResults ? [...inMemory.nodeResults] : undefined,
      };
    }

    const persisted = this.store.getWorkflowRun(runId);
    if (!persisted) {
      throw new Error(`Workflow run ${runId} not found`);
    }
    try {
      return JSON.parse(persisted.stateJson) as WorkflowRunState;
    } catch {
      throw new Error(`Workflow run ${runId} has corrupted state data`);
    }
  }

  async runWorkflow(workflowId: string, input: WorkflowRunInput): Promise<WorkflowRunState> {
    const stored = this.store.getWorkflow(workflowId);
    if (!stored) {
      throw new Error(`Workflow ${workflowId} not found`);
    }

    let graph: WorkflowGraphV1;
    try {
      graph = JSON.parse(stored.graphJson) as WorkflowGraphV1;
    } catch {
      throw new Error(`Workflow ${workflowId} has corrupted graph data`);
    }
    const compiled = this.compiler.compile(graph);

    const sessionId = input.sessionId ?? (await this.createWorkflowSession());
    const context: WorkflowExecutionContext = {
      sessionId,
      variables: {
        userInput: input.input,
      },
    };

    const runId = randomUUID();
    const state: WorkflowRunState = {
      id: runId,
      workflowId,
      status: "running",
      phase: "started",
      sessionIds: [sessionId],
      currentNodeId: compiled.startNodeId,
      nodeResults: [],
      startedAt: new Date().toISOString(),
    };

    this.persistAndPublishState(state);
    this.emitRunEvent(runId, { phase: "started", workflowId, sessionId });

    try {
      await this.executeFromNode(compiled, compiled.startNodeId, context, state, new Set<string>());
      this.updateRunState(state, {
        status: "completed",
        phase: "completed",
        currentNodeId: undefined,
        waitingOnSessionId: undefined,
        pendingApprovalId: undefined,
        endedAt: new Date().toISOString(),
      });
      this.emitRunEvent(runId, { phase: "completed" });
      const finalState = this.getRunState(runId);
      this.runs.delete(runId);
      return finalState;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.updateRunState(state, {
        status: "failed",
        phase: "failed",
        error: message,
        endedAt: new Date().toISOString(),
      });
      this.emitRunEvent(runId, { phase: "failed", error: message });
      const finalState = this.getRunState(runId);
      this.runs.delete(runId);
      return finalState;
    }
  }

  resolveApproval(decision: ApprovalDecision): { alreadyResolved: boolean; currentStatus: string } | void {
    const request = this.approvals.get(decision.requestId);
    if (!request) {
      throw new Error(`Approval request ${decision.requestId} not found`);
    }
    if (request.status !== "pending") {
      return { alreadyResolved: true, currentStatus: request.status };
    }

    request.status = decision.decision === "approved" ? "approved" : "rejected";

    const waiter = this.approvalWaiters.get(request.id);
    if (waiter) {
      clearTimeout(waiter.timeout);
      this.approvalWaiters.delete(request.id);
      const reason = decision.comment;
      this.bus.emitWs({
        type: "approval.resolved",
        runId: waiter.runId,
        requestId: request.id,
        decision: decision.decision,
        actor: decision.actor,
        reason,
      });
      if (request.status === "approved") {
        waiter.resolve(request);
      } else {
        waiter.reject(new Error(decision.comment ?? "Approval rejected"));
      }
    }

    this.approvals.delete(request.id);
  }

  private async executeFromNode(
    compiled: CompiledWorkflow,
    nodeId: string,
    context: WorkflowExecutionContext,
    state: WorkflowRunState,
    guard: Set<string>,
  ): Promise<void> {
    if (guard.has(nodeId)) {
      throw new Error(`Workflow loop detected at node ${nodeId}`);
    }
    guard.add(nodeId);

    const node = compiled.nodesById.get(nodeId);
    if (!node) {
      throw new Error(`Node ${nodeId} not found`);
    }

    this.updateRunState(state, {
      currentNodeId: nodeId,
      phase: `node_start:${node.type}`,
    });
    this.emitRunEvent(state.id, {
      phase: "node_start",
      nodeId,
      nodeType: node.type,
    });

    switch (node.type) {
      case "start":
      case "merge":
        this.appendNodeResult(state, {
          nodeId,
          status: "completed",
          completedAt: new Date().toISOString(),
        });
        break;
      case "prompt":
        await this.executePromptNode(node, context, state);
        break;
      case "tool":
        await this.executeToolNode(node, context, state);
        break;
      case "approval":
        await this.executeApprovalNode(node, context, state);
        break;
      case "condition": {
        const result = this.evaluateCondition(node.config.expression, context.variables, node.id);
        context.variables[`condition:${node.id}`] = result;
        this.appendNodeResult(state, {
          nodeId,
          status: "completed",
          output: { result },
          completedAt: new Date().toISOString(),
        });
        this.emitRunEvent(state.id, { phase: "condition_evaluated", nodeId, result });
        const next = this.pickConditionBranch(compiled, node.id, result);
        if (next) {
          await this.executeFromNode(compiled, next, context, state, guard);
        }
        return;
      }
      case "parallel": {
        await this.executeParallelNode(compiled, node, context, state, guard);
        this.appendNodeResult(state, {
          nodeId,
          status: "completed",
          completedAt: new Date().toISOString(),
        });
        return;
      }
      case "end":
        this.appendNodeResult(state, {
          nodeId,
          status: "completed",
          completedAt: new Date().toISOString(),
        });
        this.emitRunEvent(state.id, { phase: "node_end", nodeId, nodeType: node.type });
        return;
      default:
        throw new Error(`Unsupported node type ${(node as { type: string }).type}`);
    }

    this.emitRunEvent(state.id, {
      phase: "node_end",
      nodeId,
      nodeType: node.type,
    });

    const nextEdge = (compiled.outgoingEdges.get(node.id) ?? [])[0];
    if (!nextEdge) return;
    await this.executeFromNode(compiled, nextEdge.target, context, state, guard);
  }

  private async executePromptNode(
    node: Extract<WorkflowNode, { type: "prompt" }>,
    context: WorkflowExecutionContext,
    state: WorkflowRunState,
  ): Promise<void> {
    const targetSessionId = node.config.sessionId ?? context.sessionId;
    const prompt = this.interpolate(node.config.prompt, context.variables);
    const payload: SessionPromptRequest = { message: prompt };

    await this.sessions.prompt(targetSessionId, payload);
    if (!node.config.fireAndForget) {
      this.updateRunState(state, {
        waitingOnSessionId: targetSessionId,
        phase: "waiting_session_idle",
      });
      await this.sessions.waitIdle(targetSessionId, node.config.waitTimeoutMs ?? 60_000);
      this.updateRunState(state, {
        waitingOnSessionId: undefined,
      });
    }

    this.appendNodeResult(state, {
      nodeId: node.id,
      status: "completed",
      output: { sessionId: targetSessionId, fireAndForget: node.config.fireAndForget ?? false },
      completedAt: new Date().toISOString(),
    });
  }

  private async executeToolNode(
    node: Extract<WorkflowNode, { type: "tool" }>,
    context: WorkflowExecutionContext,
    state: WorkflowRunState,
  ): Promise<void> {
    const targetSessionId = node.config.sessionId ?? context.sessionId;
    const toolDescription = `Execute tool ${node.config.toolName} with args ${JSON.stringify(node.config.args)}`;
    await this.sessions.prompt(targetSessionId, { message: toolDescription });
    if (!node.config.fireAndForget) {
      this.updateRunState(state, {
        waitingOnSessionId: targetSessionId,
        phase: "waiting_session_idle",
      });
      await this.sessions.waitIdle(targetSessionId, node.config.waitTimeoutMs ?? 60_000);
      this.updateRunState(state, {
        waitingOnSessionId: undefined,
      });
    }
    this.appendNodeResult(state, {
      nodeId: node.id,
      status: "completed",
      output: { sessionId: targetSessionId, tool: node.config.toolName, fireAndForget: node.config.fireAndForget ?? false },
      completedAt: new Date().toISOString(),
    });
  }

  private async executeApprovalNode(
    node: Extract<WorkflowNode, { type: "approval" }>,
    context: WorkflowExecutionContext,
    state: WorkflowRunState,
  ): Promise<void> {
    if (node.config.policy === "never") {
      this.appendNodeResult(state, {
        nodeId: node.id,
        status: "skipped",
        completedAt: new Date().toISOString(),
      });
      return;
    }

    const request: ApprovalRequest = {
      id: randomUUID(),
      sessionId: context.sessionId,
      toolName: "workflow",
      args: { nodeId: node.id, policy: node.config.policy },
      status: "pending",
      reason: node.config.note,
      sourceNodeId: node.id,
      blocking: node.config.blocking ?? true,
      expiresAt: node.config.timeoutMs ? new Date(Date.now() + node.config.timeoutMs).toISOString() : undefined,
      createdAt: new Date().toISOString(),
    };

    this.approvals.set(request.id, request);
    this.emitRunEvent(state.id, { phase: "approval_requested", request });
    this.bus.emitWs({
      type: "approval.requested",
      runId: state.id,
      request,
    });
    this.bus.emitWs({
      type: "approval.pending",
      runId: state.id,
      requestId: request.id,
      expiresAt: request.expiresAt,
    });

    if (!request.blocking) {
      request.status = "approved";
      this.approvals.delete(request.id);
      this.appendNodeResult(state, {
        nodeId: node.id,
        status: "completed",
        output: { requestId: request.id, autoApproved: true },
        completedAt: new Date().toISOString(),
      });
      return;
    }

    this.updateRunState(state, {
      status: "waiting_approval",
      phase: "waiting_approval",
      pendingApprovalId: request.id,
    });

    try {
      await this.waitForApproval(state.id, request, node.config.timeoutMs ?? 300_000);
    } catch (error) {
      this.updateRunState(state, {
        pendingApprovalId: undefined,
        status: "failed",
        phase: "approval_timeout",
      });
      this.appendNodeResult(state, {
        nodeId: node.id,
        status: "failed",
        error: "Approval timed out",
        completedAt: new Date().toISOString(),
      });
      throw error;
    }

    this.updateRunState(state, {
      status: "running",
      pendingApprovalId: undefined,
      phase: "approval_resolved",
    });

    if (request.status === "rejected") {
      this.appendNodeResult(state, {
        nodeId: node.id,
        status: "failed",
        error: "Approval rejected",
        completedAt: new Date().toISOString(),
      });
      throw new Error("Approval rejected");
    }

    this.appendNodeResult(state, {
      nodeId: node.id,
      status: "completed",
      output: { requestId: request.id },
      completedAt: new Date().toISOString(),
    });
  }

  private async executeParallelNode(
    compiled: CompiledWorkflow,
    node: Extract<WorkflowNode, { type: "parallel" }>,
    context: WorkflowExecutionContext,
    state: WorkflowRunState,
    guard: Set<string>,
  ): Promise<void> {
    const outgoing = compiled.outgoingEdges.get(node.id) ?? [];
    const tasks = outgoing.map(
      (edge) => async (): Promise<void> => this.executeFromNode(compiled, edge.target, context, state, new Set(guard)),
    );
    const results = await this.executeTasksWithConcurrency(tasks, node.config.maxConcurrency);

    const successCount = results.filter((item) => item.ok).length;
    if (node.config.joinStrategy === "first-success") {
      if (successCount === 0) {
        throw new Error("Parallel node failed: no branch succeeded");
      }
      return;
    }

    const firstFailure = results.find((item) => !item.ok);
    if (firstFailure?.error) {
      throw firstFailure.error;
    }
  }

  private async executeTasksWithConcurrency(
    tasks: Array<() => Promise<void>>,
    maxConcurrency: number,
  ): Promise<TaskResult[]> {
    if (tasks.length === 0) return [];

    const results: TaskResult[] = new Array(tasks.length).fill(null).map(() => ({ ok: false }));
    let cursor = 0;
    const workerCount = Math.min(maxConcurrency, tasks.length);

    await Promise.all(
      new Array(workerCount).fill(null).map(async () => {
        while (true) {
          const index = cursor;
          cursor += 1;
          if (index >= tasks.length) return;
          const task = tasks[index];
          if (!task) return;
          try {
            await task();
            results[index] = { ok: true };
          } catch (error) {
            results[index] = { ok: false, error: error instanceof Error ? error : new Error(String(error)) };
          }
        }
      }),
    );

    return results;
  }

  private evaluateCondition(expression: string, variables: Record<string, unknown>, nodeId: string): boolean {
    try {
      return evaluateSafeCondition(expression, variables);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`Condition evaluation failed at node ${nodeId}: ${message}`);
    }
  }

  private pickConditionBranch(compiled: CompiledWorkflow, nodeId: string, result: boolean): string | null {
    const edges = compiled.outgoingEdges.get(nodeId) ?? [];
    const desiredLabel = result ? "true" : "false";
    const labelled = edges.find((edge) => (edge.label ?? "").toLowerCase() === desiredLabel);
    if (labelled) return labelled.target;

    const fallback = result ? edges[0] : edges[1] ?? edges[0];
    return fallback?.target ?? null;
  }

  private interpolate(text: string, variables: Record<string, unknown>): string {
    return text.replace(/\{\{\s*([\w:.\-]+)\s*\}\}/g, (_all, key) => {
      const value = variables[key];
      return value === undefined ? "" : String(value);
    });
  }

  private async waitForApproval(runId: string, request: ApprovalRequest, timeoutMs: number): Promise<ApprovalRequest> {
    return await new Promise<ApprovalRequest>((resolve, reject) => {
      const emitHeartbeat = () => {
        const remaining = Math.max(0, timeoutMs - (Date.now() - new Date(request.createdAt).getTime()));
        this.bus.emitWs({
          type: "approval.heartbeat",
          runId,
          requestId: request.id,
          remainingMs: remaining,
        });
      };

      emitHeartbeat();
      const heartbeatInterval = setInterval(() => {
        emitHeartbeat();
      }, 5_000);

      const timeout = setTimeout(() => {
        clearInterval(heartbeatInterval);
        this.approvalWaiters.delete(request.id);
        request.status = "rejected";
        this.approvals.delete(request.id);
        this.bus.emitWs({
          type: "approval.heartbeat",
          runId,
          requestId: request.id,
          remainingMs: 0,
        });
        this.bus.emitWs({
          type: "approval.resolved",
          runId,
          requestId: request.id,
          decision: "rejected",
          actor: "system",
          reason: "timeout",
        });
        reject(new Error(`Approval ${request.id} timed out`));
      }, timeoutMs);

      const originalResolve = (req: ApprovalRequest) => {
        clearInterval(heartbeatInterval);
        resolve(req);
      };
      const originalReject = (error: Error) => {
        clearInterval(heartbeatInterval);
        reject(error);
      };

      this.approvalWaiters.set(request.id, {
        runId,
        timeout,
        resolve: originalResolve,
        reject: originalReject,
      });
    });
  }

  private appendNodeResult(state: WorkflowRunState, result: WorkflowNodeResult): void {
    if (!state.nodeResults) {
      state.nodeResults = [];
    }
    state.nodeResults.push(result);
    this.updateRunState(state, { nodeResults: [...state.nodeResults] });
  }

  private updateRunState(state: WorkflowRunState, patch: Partial<WorkflowRunState>): void {
    Object.assign(state, patch);
    this.persistAndPublishState(state);
  }

  private persistAndPublishState(state: WorkflowRunState): void {
    this.runs.set(state.id, {
      ...state,
      nodeResults: state.nodeResults ? [...state.nodeResults] : undefined,
    });

    const now = new Date().toISOString();
    this.store.upsertWorkflowRun({
      id: state.id,
      workflowId: state.workflowId,
      stateJson: JSON.stringify(state),
      createdAt: state.startedAt,
      updatedAt: now,
    });

    this.bus.emitWs({
      type: "workflow.run.state",
      runId: state.id,
      state,
    });

    if (state.pendingApprovalId) {
      this.bus.emitWs({
        type: "approval.pending",
        runId: state.id,
        requestId: state.pendingApprovalId,
        expiresAt: state.pendingApprovalId ? this.approvals.get(state.pendingApprovalId)?.expiresAt : undefined,
      });
    }
  }

  private emitRunEvent(runId: string, event: Record<string, unknown>): void {
    this.bus.emitWs({
      type: "workflow.run.event",
      runId,
      event,
    });
  }

  private validateGraphFeasibility(compiled: CompiledWorkflow, errors: string[], warnings: string[]): void {
    const reachable = new Set<string>();
    const visit = (nodeId: string) => {
      if (reachable.has(nodeId)) return;
      reachable.add(nodeId);
      for (const edge of compiled.outgoingEdges.get(nodeId) ?? []) {
        visit(edge.target);
      }
    };

    visit(compiled.startNodeId);

    for (const nodeId of compiled.nodesById.keys()) {
      if (!reachable.has(nodeId)) {
        warnings.push(`Node ${nodeId} is unreachable from start node ${compiled.startNodeId}`);
      }
    }

    const hasEndNode = Array.from(compiled.nodesById.values()).some((node) => node.type === "end");
    if (!hasEndNode) {
      errors.push("Workflow must include at least one end node");
    }
  }

  private async createWorkflowSession(): Promise<string> {
    const request: CreateSessionRequest = {
      cwd: process.cwd(),
      runtimeChannel: "stable",
    };
    const created = await this.sessions.createSession(request);
    return created.sessionId;
  }
}
