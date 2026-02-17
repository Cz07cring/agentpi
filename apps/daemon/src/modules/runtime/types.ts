import type { RuntimeChannel } from "@agentpi/protocol";

export interface RuntimeManifest {
  stableVersion: string | null;
  betaVersion: string | null;
  canaryVersion: string | null;
  canaryPercentage: number;
  lastUpdatedAt: string | null;
}

export interface ResolvedRuntime {
  version: string;
  channel: RuntimeChannel;
  rootDir: string;
  cliPath: string;
}

export interface RuntimeHealthResult {
  ok: boolean;
  details?: string;
}

export interface RuntimeUpdateProgress {
  phase: "checking" | "downloading" | "health_check" | "promoting" | "done" | "failed";
  message: string;
}
