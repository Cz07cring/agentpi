import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { randomUUID } from "node:crypto";
import type { DaemonEventBus } from "../../lib/event-bus.js";

interface TerminalBinding {
  id: string;
  process: ChildProcessWithoutNullStreams;
}

export class TerminalService {
  private readonly terminals = new Map<string, TerminalBinding>();

  constructor(private readonly bus: DaemonEventBus) {}

  start(cwd: string, shell = process.env.SHELL ?? "bash"): string {
    const id = randomUUID();
    const filteredEnv = { ...process.env };
    delete filteredEnv.AGENTPI_DAEMON_TOKEN;
    const child = spawn(shell, [], {
      cwd,
      env: filteredEnv,
      stdio: "pipe",
    });

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");

    child.stdout.on("data", (chunk: string) => {
      this.bus.emitWs({ type: "terminal.output", terminalId: id, chunk });
    });

    child.stderr.on("data", (chunk: string) => {
      this.bus.emitWs({ type: "terminal.output", terminalId: id, chunk });
    });

    child.on("close", (code, signal) => {
      this.terminals.delete(id);
      this.bus.emitWs({ type: "terminal.closed", terminalId: id, code, signal });
    });

    this.terminals.set(id, { id, process: child });
    return id;
  }

  write(terminalId: string, input: string): void {
    const terminal = this.terminals.get(terminalId);
    if (!terminal) throw new Error(`terminal ${terminalId} not found`);
    terminal.process.stdin.write(input);
  }

  stop(terminalId: string): void {
    const terminal = this.terminals.get(terminalId);
    if (!terminal) return;
    terminal.process.kill("SIGTERM");
    this.terminals.delete(terminalId);
  }
}
