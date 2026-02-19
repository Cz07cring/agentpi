import { spawn } from "node:child_process";

export interface RunCommandResult {
  code: number;
  stdout: string;
  stderr: string;
}

export interface RunCommandOptions {
  cwd?: string;
  env?: Record<string, string | undefined>;
  timeoutMs?: number;
  stdin?: string;
}

export interface CommandRunner {
  run(command: string, args: string[], options?: RunCommandOptions): Promise<RunCommandResult>;
}

const MAX_OUTPUT_BYTES = 10 * 1024 * 1024; // 10 MB

export class NodeCommandRunner implements CommandRunner {
  async run(command: string, args: string[], options: RunCommandOptions = {}): Promise<RunCommandResult> {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: { ...process.env, ...(options.env ?? {}) },
      stdio: "pipe",
    });

    let stdout = "";
    let stderr = "";
    let timedOut = false;
    let timeout: NodeJS.Timeout | undefined;

    if (options.timeoutMs && options.timeoutMs > 0) {
      timeout = setTimeout(() => {
        timedOut = true;
        child.kill("SIGTERM");
      }, options.timeoutMs);
    }

    child.stdout.on("data", (chunk) => {
      if (stdout.length < MAX_OUTPUT_BYTES) {
        stdout += chunk.toString();
      }
    });

    child.stderr.on("data", (chunk) => {
      if (stderr.length < MAX_OUTPUT_BYTES) {
        stderr += chunk.toString();
      }
    });

    if (options.stdin) {
      child.stdin.write(options.stdin);
    }
    child.stdin.end();

    return await new Promise<RunCommandResult>((resolve, reject) => {
      child.on("error", reject);
      child.on("close", (code) => {
        if (timeout) clearTimeout(timeout);
        if (timedOut) {
          reject(new Error(`Command timed out after ${options.timeoutMs}ms: ${command}`));
          return;
        }
        resolve({ code: code ?? 1, stdout, stderr });
      });
    });
  }
}
