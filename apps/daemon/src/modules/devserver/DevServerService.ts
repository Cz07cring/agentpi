import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { randomUUID } from "node:crypto";

export interface DevServerProcess {
  id: string;
  command: string;
  args: string[];
  cwd: string;
  process: ChildProcessWithoutNullStreams;
}

export class DevServerService {
  private readonly servers = new Map<string, DevServerProcess>();

  start(command: string, args: string[], cwd: string): string {
    const id = randomUUID();
    const child = spawn(command, args, { cwd, stdio: "pipe", env: process.env });

    this.servers.set(id, {
      id,
      command,
      args,
      cwd,
      process: child,
    });

    child.on("close", () => {
      this.servers.delete(id);
    });

    return id;
  }

  stop(id: string): void {
    const server = this.servers.get(id);
    if (!server) return;
    server.process.kill("SIGTERM");
    this.servers.delete(id);
  }

  stopAll(): void {
    for (const id of this.servers.keys()) {
      this.stop(id);
    }
  }
}
