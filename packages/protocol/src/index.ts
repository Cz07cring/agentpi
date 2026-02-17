import { z } from "zod";

export const RuntimeChannelSchema = z.enum(["stable", "beta"]);
export type RuntimeChannel = z.infer<typeof RuntimeChannelSchema>;

export const PiRuntimeVersionSchema = z.object({
  version: z.string().min(1),
  channel: RuntimeChannelSchema,
  path: z.string().min(1),
  installedAt: z.string().datetime(),
  healthy: z.boolean(),
});
export type PiRuntimeVersion = z.infer<typeof PiRuntimeVersionSchema>;

export const SessionRuntimeBindingSchema = z.object({
  sessionId: z.string().uuid(),
  runtimeVersion: z.string().min(1),
  channel: RuntimeChannelSchema,
  pinned: z.boolean().default(true),
  createdAt: z.string().datetime(),
});
export type SessionRuntimeBinding = z.infer<typeof SessionRuntimeBindingSchema>;

export const SessionRuntimeStateSchema = z.object({
  sessionId: z.string().uuid(),
  runtimeSessionId: z.string().min(1).optional(),
  runtimeVersion: z.string().min(1),
  status: z.enum(["unknown", "running", "idle", "closed"]),
  isStreaming: z.boolean().default(false),
  lastEventAt: z.string().datetime().optional(),
});
export type SessionRuntimeState = z.infer<typeof SessionRuntimeStateSchema>;

const WorkflowNodeBaseSchema = z.object({
  id: z.string().min(1),
  label: z.string().min(1),
});

export const WorkflowPromptNodeSchema = WorkflowNodeBaseSchema.extend({
  type: z.literal("prompt"),
  config: z.object({
    prompt: z.string().min(1),
    sessionId: z.string().uuid().optional(),
    fireAndForget: z.boolean().optional(),
    waitTimeoutMs: z.number().int().positive().max(600_000).optional(),
  }),
});

export const WorkflowToolNodeSchema = WorkflowNodeBaseSchema.extend({
  type: z.literal("tool"),
  config: z.object({
    toolName: z.string().min(1),
    args: z.record(z.string(), z.unknown()).default({}),
    sessionId: z.string().uuid().optional(),
    fireAndForget: z.boolean().optional(),
    waitTimeoutMs: z.number().int().positive().max(600_000).optional(),
  }),
});

export const WorkflowConditionNodeSchema = WorkflowNodeBaseSchema.extend({
  type: z.literal("condition"),
  config: z.object({
    expression: z.string().min(1),
  }),
});

export const WorkflowParallelNodeSchema = WorkflowNodeBaseSchema.extend({
  type: z.literal("parallel"),
  config: z.object({
    maxConcurrency: z.number().int().positive().default(4),
    joinStrategy: z.enum(["wait-all", "first-success"]).optional(),
  }),
});

export const WorkflowMergeNodeSchema = WorkflowNodeBaseSchema.extend({
  type: z.literal("merge"),
  config: z.object({
    strategy: z.enum(["wait-all", "first-success"]).default("wait-all"),
  }),
});

export const WorkflowApprovalNodeSchema = WorkflowNodeBaseSchema.extend({
  type: z.literal("approval"),
  config: z.object({
    policy: z.enum(["always", "on-dangerous-tools", "never"]),
    note: z.string().optional(),
    blocking: z.boolean().optional(),
    timeoutMs: z.number().int().positive().max(3_600_000).optional(),
  }),
});

export const WorkflowEndNodeSchema = WorkflowNodeBaseSchema.extend({
  type: z.literal("end"),
  config: z.object({
    success: z.boolean().default(true),
  }),
});

export const WorkflowStartNodeSchema = WorkflowNodeBaseSchema.extend({
  type: z.literal("start"),
  config: z.object({}),
});

export const WorkflowNodeSchema = z.discriminatedUnion("type", [
  WorkflowStartNodeSchema,
  WorkflowPromptNodeSchema,
  WorkflowToolNodeSchema,
  WorkflowConditionNodeSchema,
  WorkflowParallelNodeSchema,
  WorkflowMergeNodeSchema,
  WorkflowApprovalNodeSchema,
  WorkflowEndNodeSchema,
]);
export type WorkflowNode = z.infer<typeof WorkflowNodeSchema>;

export const WorkflowEdgeSchema = z.object({
  id: z.string().min(1),
  source: z.string().min(1),
  target: z.string().min(1),
  label: z.string().optional(),
});
export type WorkflowEdge = z.infer<typeof WorkflowEdgeSchema>;

export const WorkflowGraphV1Schema = z.object({
  version: z.literal(1),
  name: z.string().min(1),
  nodes: z.array(WorkflowNodeSchema).min(1),
  edges: z.array(WorkflowEdgeSchema).default([]),
});
export type WorkflowGraphV1 = z.infer<typeof WorkflowGraphV1Schema>;

export const WorkflowRunStatusSchema = z.enum([
  "queued",
  "running",
  "waiting_approval",
  "completed",
  "failed",
  "cancelled",
]);
export type WorkflowRunStatus = z.infer<typeof WorkflowRunStatusSchema>;

export const WorkflowNodeResultSchema = z.object({
  nodeId: z.string().min(1),
  status: z.enum(["completed", "failed", "skipped"]),
  output: z.record(z.string(), z.unknown()).optional(),
  error: z.string().optional(),
  completedAt: z.string().datetime(),
});
export type WorkflowNodeResult = z.infer<typeof WorkflowNodeResultSchema>;

export const WorkflowRunStateSchema = z.object({
  id: z.string().uuid(),
  workflowId: z.string().uuid(),
  status: WorkflowRunStatusSchema,
  phase: z.string().optional(),
  sessionIds: z.array(z.string().uuid()),
  currentNodeId: z.string().optional(),
  pendingApprovalId: z.string().uuid().optional(),
  waitingOnSessionId: z.string().uuid().optional(),
  nodeResults: z.array(WorkflowNodeResultSchema).optional(),
  startedAt: z.string().datetime(),
  endedAt: z.string().datetime().optional(),
  error: z.string().optional(),
});
export type WorkflowRunState = z.infer<typeof WorkflowRunStateSchema>;

export const ApprovalRequestSchema = z.object({
  id: z.string().uuid(),
  sessionId: z.string().uuid(),
  toolName: z.string().min(1),
  args: z.record(z.string(), z.unknown()),
  status: z.enum(["pending", "approved", "rejected"]),
  reason: z.string().optional(),
  expiresAt: z.string().datetime().optional(),
  sourceNodeId: z.string().min(1).optional(),
  blocking: z.boolean().default(true),
  createdAt: z.string().datetime(),
});
export type ApprovalRequest = z.infer<typeof ApprovalRequestSchema>;

export const ApprovalDecisionSchema = z.object({
  id: z.string().uuid(),
  requestId: z.string().uuid(),
  decision: z.enum(["approved", "rejected"]),
  actor: z.string().min(1),
  comment: z.string().optional(),
  decidedAt: z.string().datetime(),
});
export type ApprovalDecision = z.infer<typeof ApprovalDecisionSchema>;

export const CreateSessionRequestSchema = z.object({
  cwd: z.string().min(1).optional(),
  runtimeChannel: RuntimeChannelSchema.default("stable"),
  provider: z.string().optional(),
  model: z.string().optional(),
});
export type CreateSessionRequest = z.infer<typeof CreateSessionRequestSchema>;

export const CreateSessionResponseSchema = z.object({
  sessionId: z.string().uuid(),
  binding: SessionRuntimeBindingSchema,
});
export type CreateSessionResponse = z.infer<typeof CreateSessionResponseSchema>;

export const SessionPromptRequestSchema = z.object({
  message: z.string().min(1),
  images: z
    .array(
      z.object({
        type: z.literal("image"),
        data: z.string().min(1),
        mimeType: z.string().min(1),
      }),
    )
    .optional(),
  streamingBehavior: z.enum(["steer", "followUp"]).optional(),
});
export type SessionPromptRequest = z.infer<typeof SessionPromptRequestSchema>;

export const SessionStateResponseSchema = z.object({
  sessionId: z.string().uuid(),
  state: z.record(z.string(), z.unknown()),
});
export type SessionStateResponse = z.infer<typeof SessionStateResponseSchema>;

export const SessionRuntimeStateResponseSchema = z.object({
  sessionId: z.string().uuid(),
  runtimeState: SessionRuntimeStateSchema,
});
export type SessionRuntimeStateResponse = z.infer<typeof SessionRuntimeStateResponseSchema>;

export const WaitSessionIdleRequestSchema = z.object({
  timeoutMs: z.number().int().positive().max(600_000).default(60_000),
});
export type WaitSessionIdleRequest = z.infer<typeof WaitSessionIdleRequestSchema>;

export const WaitSessionIdleResponseSchema = z.object({
  sessionId: z.string().uuid(),
  runtimeState: SessionRuntimeStateSchema,
});
export type WaitSessionIdleResponse = z.infer<typeof WaitSessionIdleResponseSchema>;

export const CreateWorktreeRequestSchema = z.object({
  repoPath: z.string().min(1),
  branchName: z.string().min(1),
  directoryName: z.string().min(1),
  startPoint: z.string().optional(),
});
export type CreateWorktreeRequest = z.infer<typeof CreateWorktreeRequestSchema>;

export const CreateWorktreeResponseSchema = z.object({
  worktreePath: z.string().min(1),
  branchName: z.string().min(1),
});
export type CreateWorktreeResponse = z.infer<typeof CreateWorktreeResponseSchema>;

export const CreateWorkflowRequestSchema = z.object({
  graph: WorkflowGraphV1Schema,
});
export type CreateWorkflowRequest = z.infer<typeof CreateWorkflowRequestSchema>;

export const CreateWorkflowResponseSchema = z.object({
  workflowId: z.string().uuid(),
});
export type CreateWorkflowResponse = z.infer<typeof CreateWorkflowResponseSchema>;

export const RunWorkflowRequestSchema = z.object({
  input: z.string().optional(),
  sessionId: z.string().uuid().optional(),
});
export type RunWorkflowRequest = z.infer<typeof RunWorkflowRequestSchema>;

export const RunWorkflowResponseSchema = z.object({
  runId: z.string().uuid(),
  state: WorkflowRunStateSchema,
});
export type RunWorkflowResponse = z.infer<typeof RunWorkflowResponseSchema>;

export const GetWorkflowRunResponseSchema = z.object({
  runId: z.string().uuid(),
  state: WorkflowRunStateSchema,
});
export type GetWorkflowRunResponse = z.infer<typeof GetWorkflowRunResponseSchema>;

export const ValidateWorkflowResponseSchema = z.object({
  workflowId: z.string().uuid(),
  valid: z.boolean(),
  errors: z.array(z.string()).default([]),
  warnings: z.array(z.string()).default([]),
});
export type ValidateWorkflowResponse = z.infer<typeof ValidateWorkflowResponseSchema>;

export const ApprovalDecisionInputSchema = z.object({
  decision: z.enum(["approved", "rejected"]),
  actor: z.string().min(1).default("local-user"),
  comment: z.string().optional(),
});
export type ApprovalDecisionInput = z.infer<typeof ApprovalDecisionInputSchema>;

export const CheckRuntimeUpdateRequestSchema = z.object({
  channel: RuntimeChannelSchema.default("stable"),
});
export type CheckRuntimeUpdateRequest = z.infer<typeof CheckRuntimeUpdateRequestSchema>;

export const CheckRuntimeUpdateResponseSchema = z.object({
  channel: RuntimeChannelSchema,
  currentVersion: z.string().nullable(),
  latestVersion: z.string().nullable(),
  hasUpdate: z.boolean(),
});
export type CheckRuntimeUpdateResponse = z.infer<typeof CheckRuntimeUpdateResponseSchema>;

export const ApplyRuntimeUpdateRequestSchema = z.object({
  channel: RuntimeChannelSchema.default("stable"),
  targetVersion: z.string().optional(),
  promoteToStable: z.boolean().default(true),
});
export type ApplyRuntimeUpdateRequest = z.infer<typeof ApplyRuntimeUpdateRequestSchema>;

export const ApplyRuntimeUpdateResponseSchema = z.object({
  status: z.enum(["updated", "already_latest", "failed"]),
  previousVersion: z.string().nullable(),
  newVersion: z.string().nullable(),
  health: z.object({
    ok: z.boolean(),
    details: z.string().optional(),
  }),
});
export type ApplyRuntimeUpdateResponse = z.infer<typeof ApplyRuntimeUpdateResponseSchema>;

export const WsSessionEventSchema = z.object({
  type: z.literal("session.event"),
  sessionId: z.string().uuid(),
  event: z.record(z.string(), z.unknown()),
});
export type WsSessionEvent = z.infer<typeof WsSessionEventSchema>;

export const WsSessionStateSchema = z.object({
  type: z.literal("session.state"),
  sessionId: z.string().uuid(),
  state: z.record(z.string(), z.unknown()),
});
export type WsSessionState = z.infer<typeof WsSessionStateSchema>;

export const WsWorkflowRunEventSchema = z.object({
  type: z.literal("workflow.run.event"),
  runId: z.string().uuid(),
  event: z.record(z.string(), z.unknown()),
});
export type WsWorkflowRunEvent = z.infer<typeof WsWorkflowRunEventSchema>;

export const WsRuntimeUpdateStateSchema = z.object({
  type: z.literal("runtime.update.state"),
  channel: RuntimeChannelSchema,
  state: z.object({
    phase: z.enum(["checking", "downloading", "health_check", "promoting", "done", "failed"]),
    message: z.string(),
  }),
});
export type WsRuntimeUpdateState = z.infer<typeof WsRuntimeUpdateStateSchema>;

export const WsTerminalOutputSchema = z.object({
  type: z.literal("terminal.output"),
  terminalId: z.string().uuid(),
  chunk: z.string(),
});
export type WsTerminalOutput = z.infer<typeof WsTerminalOutputSchema>;

export const WsApprovalRequestedSchema = z.object({
  type: z.literal("approval.requested"),
  runId: z.string().uuid(),
  request: ApprovalRequestSchema,
});
export type WsApprovalRequested = z.infer<typeof WsApprovalRequestedSchema>;

export const WsApprovalResolvedSchema = z.object({
  type: z.literal("approval.resolved"),
  runId: z.string().uuid(),
  requestId: z.string().uuid(),
  decision: z.enum(["approved", "rejected"]),
  actor: z.string().min(1),
});
export type WsApprovalResolved = z.infer<typeof WsApprovalResolvedSchema>;

export const WsWorkflowRunStateSchema = z.object({
  type: z.literal("workflow.run.state"),
  runId: z.string().uuid(),
  state: WorkflowRunStateSchema,
});
export type WsWorkflowRunState = z.infer<typeof WsWorkflowRunStateSchema>;

export const WsEventSchema = z.discriminatedUnion("type", [
  WsSessionEventSchema,
  WsSessionStateSchema,
  WsWorkflowRunEventSchema,
  WsRuntimeUpdateStateSchema,
  WsTerminalOutputSchema,
  WsApprovalRequestedSchema,
  WsApprovalResolvedSchema,
  WsWorkflowRunStateSchema,
]);
export type WsEvent = z.infer<typeof WsEventSchema>;

export function parseOrThrow<T>(schema: z.ZodSchema<T>, input: unknown): T {
  const result = schema.safeParse(input);
  if (!result.success) {
    throw new Error(result.error.message);
  }
  return result.data;
}
