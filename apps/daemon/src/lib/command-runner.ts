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

export class NodeCommandRunner implements CommandRunner {
  async run(command: string, args: string[], options: RunCommandOptions = {}): Promise<RunCommandResult> {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: { ...process.env, ...(options.env ?? {}) },
      stdio: "pipe",
    });

    let stdout = "";
    let stderr = "";
    let timeout: NodeJS.Timeout | undefined;

    if (options.timeoutMs && options.timeoutMs > 0) {
      timeout = setTimeout(() => {
        child.kill("SIGTERM");
      }, options.timeoutMs);
    }

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    if (options.stdin) {
      child.stdin.write(options.stdin);
    }
    child.stdin.end();

    return await new Promise<RunCommandResult>((resolve, reject) => {
      child.on("error", reject);
      child.on("close", (code) => {
        if (timeout) clearTimeout(timeout);
        resolve({ code: code ?? 1, stdout, stderr });
      });
    });
  }
}
