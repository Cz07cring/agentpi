import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { randomUUID } from "node:crypto";
import type { DaemonEventBus } from "../../lib/event-bus.js";

export interface DevServerProcess {
  id: string;
  command: string;
  args: string[];
  cwd: string;
  process: ChildProcessWithoutNullStreams;
}

export class DevServerService {
  private readonly servers = new Map<string, DevServerProcess>();

  constructor(private readonly bus?: DaemonEventBus) {}

  start(command: string, args: string[], cwd: string): string {
    const id = randomUUID();
    const env = { ...process.env } as NodeJS.ProcessEnv;
    delete env.AGENTPI_DAEMON_TOKEN;
    const child = spawn(command, args, { cwd, stdio: "pipe", env });

    this.servers.set(id, {
      id,
      command,
      args,
      cwd,
      process: child,
    });

    child.on("close", (code, signal) => {
      this.servers.delete(id);
      this.bus?.emitWs({
        type: "session.event",
        sessionId: id,
        event: { type: "devserver.closed", devServerId: id, code, signal },
      });
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
