import { existsSync } from "node:fs";
import { basename, isAbsolute, join, resolve } from "node:path";
import { NodeCommandRunner, type CommandRunner } from "../../lib/command-runner.js";

export interface CreateWorktreeInput {
  repoPath: string;
  branchName: string;
  directoryName: string;
  startPoint?: string;
}

export class WorktreeService {
  private readonly runner: CommandRunner;

  constructor(runner: CommandRunner = new NodeCommandRunner()) {
    this.runner = runner;
  }

  async createWorktree(input: CreateWorktreeInput): Promise<{ worktreePath: string; branchName: string }> {
    const repoPath = resolve(input.repoPath);
    if (!existsSync(join(repoPath, ".git"))) {
      throw new Error(`Not a git repository: ${repoPath}`);
    }
    if (!/^[\w./-]+$/.test(input.branchName) || input.branchName.startsWith("-")) {
      throw new Error("Invalid branch name");
    }
    if (!/^[\w.-]+$/.test(input.directoryName)) {
      throw new Error("Invalid directory name");
    }
    if (input.startPoint && (!/^[\w./-]+$/.test(input.startPoint) || input.startPoint.startsWith("-"))) {
      throw new Error("Invalid startPoint");
    }

    const parentDir = join(repoPath, "..");
    const worktreePath = join(parentDir, input.directoryName);

    const args = ["worktree", "add", "-b", input.branchName, worktreePath];
    if (input.startPoint) {
      args.push(input.startPoint);
    }

    const result = await this.runner.run("git", args, {
      cwd: repoPath,
      timeoutMs: 30_000,
    });

    if (result.code !== 0) {
      throw new Error(result.stderr || result.stdout || "Failed to create worktree");
    }

    return {
      worktreePath,
      branchName: input.branchName,
    };
  }

  async removeWorktree(worktreePath: string): Promise<void> {
    const normalized = resolve(worktreePath);
    if (!existsSync(normalized)) {
      throw new Error(`Worktree path does not exist: ${normalized}`);
    }
    if (!existsSync(join(normalized, ".git"))) {
      throw new Error(`Worktree path is not a git worktree: ${normalized}`);
    }

    const result = await this.runner.run("git", ["worktree", "remove", "--force", normalized], {
      cwd: normalized,
      timeoutMs: 30_000,
    });

    if (result.code !== 0) {
      throw new Error(result.stderr || result.stdout || "Failed to remove worktree");
    }
  }

  async prune(repoPath: string): Promise<void> {
    const result = await this.runner.run("git", ["worktree", "prune"], { cwd: repoPath, timeoutMs: 15_000 });
    if (result.code !== 0) {
      throw new Error(result.stderr || result.stdout || "Failed to prune worktrees");
    }
  }

  async inferWorktreeId(worktreePath: string): Promise<string> {
    return Buffer.from(worktreePath, "utf8").toString("base64url") || basename(worktreePath);
  }

  decodeWorktreeId(id: string): string {
    try {
      const decoded = Buffer.from(id, "base64url").toString("utf8");
      if (!decoded || decoded.includes("\0") || /\.\.[\\/]/.test(decoded)) {
        throw new Error("Invalid worktree id");
      }
      if (!isAbsolute(decoded)) {
        throw new Error("Worktree id must decode to absolute path");
      }
      return decoded;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`Invalid worktree id: ${message}`);
    }
  }
}
