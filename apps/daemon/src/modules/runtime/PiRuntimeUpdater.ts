import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type {
  ApplyRuntimeUpdateResponse,
  CheckRuntimeUpdateResponse,
  RuntimeChannel,
} from "@agentpi/protocol";
import { NodeCommandRunner, type CommandRunner } from "../../lib/command-runner.js";
import { log } from "../../lib/logger.js";
import type { ResolvedRuntime, RuntimeHealthResult, RuntimeManifest, RuntimeUpdateProgress } from "./types.js";

const PACKAGE_NAME = "@mariozechner/pi-coding-agent";

function getDefaultManifest(): RuntimeManifest {
  return {
    stableVersion: null,
    betaVersion: null,
    canaryVersion: null,
    canaryPercentage: 0,
    lastUpdatedAt: null,
  };
}

export class PiRuntimeUpdater {
  private readonly baseDir: string;
  private readonly manifestPath: string;
  private readonly runner: CommandRunner;

  constructor(
    options: {
      baseDir?: string;
      manifestPath?: string;
      runner?: CommandRunner;
    } = {},
  ) {
    const root = join(homedir(), ".agentpi");
    this.baseDir = options.baseDir ?? join(root, "runtimes", "pi");
    this.manifestPath = options.manifestPath ?? join(root, "runtime-manifest.json");
    this.runner = options.runner ?? new NodeCommandRunner();

    mkdirSync(this.baseDir, { recursive: true });
    mkdirSync(join(root, "runtimes"), { recursive: true });
  }

  private readManifest(): RuntimeManifest {
    if (!existsSync(this.manifestPath)) {
      const initial = getDefaultManifest();
      this.writeManifest(initial);
      return initial;
    }

    try {
      const parsed = JSON.parse(readFileSync(this.manifestPath, "utf8")) as RuntimeManifest;
      return {
        ...getDefaultManifest(),
        ...parsed,
      };
    } catch {
      return getDefaultManifest();
    }
  }

  private writeManifest(manifest: RuntimeManifest): void {
    mkdirSync(dirname(this.manifestPath), { recursive: true });
    writeFileSync(this.manifestPath, JSON.stringify(manifest, null, 2));
  }

  private runtimeDirFor(version: string): string {
    return join(this.baseDir, version);
  }

  private cliPathFor(version: string): string {
    return join(this.runtimeDirFor(version), "node_modules", "@mariozechner", "pi-coding-agent", "dist", "cli.js");
  }

  private async getLatestVersion(channel: RuntimeChannel): Promise<string | null> {
    if (channel === "stable") {
      const result = await this.runner.run("npm", ["view", PACKAGE_NAME, "version"], { timeoutMs: 20_000 });
      if (result.code !== 0) return null;
      return result.stdout.trim() || null;
    }

    const betaResult = await this.runner.run("npm", ["view", PACKAGE_NAME, "dist-tags.beta"], { timeoutMs: 20_000 });
    if (betaResult.code !== 0) return null;
    const beta = betaResult.stdout.trim();
    if (!beta) {
      const fallback = await this.runner.run("npm", ["view", PACKAGE_NAME, "version"], { timeoutMs: 20_000 });
      if (fallback.code !== 0) return null;
      return fallback.stdout.trim() || null;
    }
    return beta;
  }

  async checkForUpdate(channel: RuntimeChannel): Promise<CheckRuntimeUpdateResponse> {
    const manifest = this.readManifest();
    const latestVersion = await this.getLatestVersion(channel);
    const currentVersion = channel === "stable" ? manifest.stableVersion : (manifest.betaVersion ?? manifest.stableVersion);

    return {
      channel,
      currentVersion,
      latestVersion,
      hasUpdate: Boolean(latestVersion && latestVersion !== currentVersion),
    };
  }

  private async installVersion(version: string): Promise<void> {
    const runtimeDir = this.runtimeDirFor(version);
    mkdirSync(runtimeDir, { recursive: true });

    const packageJson = join(runtimeDir, "package.json");
    if (!existsSync(packageJson)) {
      writeFileSync(
        packageJson,
        JSON.stringify(
          {
            name: `agentpi-runtime-${version}`,
            private: true,
            version: "0.0.0",
            type: "module",
          },
          null,
          2,
        ),
      );
    }

    const installResult = await this.runner.run(
      "npm",
      ["install", "--no-audit", "--no-fund", `${PACKAGE_NAME}@${version}`],
      { cwd: runtimeDir, timeoutMs: 180_000 },
    );

    if (installResult.code !== 0) {
      throw new Error(`Failed to install runtime ${version}: ${installResult.stderr || installResult.stdout}`);
    }
  }

  async ensureInstalled(version: string, channel: RuntimeChannel): Promise<ResolvedRuntime> {
    const cliPath = this.cliPathFor(version);
    if (!existsSync(cliPath)) {
      await this.installVersion(version);
    }

    if (!existsSync(cliPath)) {
      throw new Error(`Runtime ${version} missing cli entry at ${cliPath}`);
    }

    return {
      version,
      channel,
      rootDir: this.runtimeDirFor(version),
      cliPath,
    };
  }

  async healthCheck(runtime: ResolvedRuntime): Promise<RuntimeHealthResult> {
    return await new Promise<RuntimeHealthResult>((resolve) => {
      const child = spawn(process.execPath, [runtime.cliPath, "--mode", "rpc"], {
        stdio: ["pipe", "pipe", "pipe"],
      });

      let done = false;
      const forceKill = () => {
        setTimeout(() => {
          try { child.kill("SIGKILL"); } catch { /* already dead */ }
        }, 3_000);
      };
      const timeout = setTimeout(() => {
        if (!done) {
          done = true;
          child.kill("SIGTERM");
          forceKill();
          resolve({ ok: false, details: "health check timeout" });
        }
      }, 15_000);

      const finish = (result: RuntimeHealthResult) => {
        if (done) return;
        done = true;
        clearTimeout(timeout);
        child.kill("SIGTERM");
        resolve(result);
      };

      child.stdout.setEncoding("utf8");
      child.stdout.on("data", (chunk: string) => {
        const lines = chunk.split(/\r?\n/).filter(Boolean);
        for (const line of lines) {
          try {
            const parsed = JSON.parse(line) as { type?: string; command?: string; success?: boolean };
            if (parsed.type === "response" && parsed.command === "get_state") {
              finish({ ok: parsed.success === true, details: parsed.success ? "ok" : "get_state failed" });
              return;
            }
          } catch {
            // Ignore non-json lines.
          }
        }
      });

      child.on("error", (error) => {
        finish({ ok: false, details: error.message });
      });

      child.on("spawn", () => {
        child.stdin.write(JSON.stringify({ id: "health-check", type: "get_state" }) + "\n");
      });
    });
  }

  async selectRuntimeForNewSession(channel: RuntimeChannel, sessionIdSeed?: string): Promise<ResolvedRuntime> {
    const manifest = this.readManifest();

    let selectedVersion: string | null = null;
    if (channel === "stable") {
      const canaryActive = manifest.canaryVersion && manifest.canaryPercentage > 0 && sessionIdSeed;
      if (canaryActive) {
        const hash = Array.from(sessionIdSeed).reduce((acc, char) => acc + char.charCodeAt(0), 0) % 100;
        if (hash < manifest.canaryPercentage) {
          selectedVersion = manifest.canaryVersion;
        }
      }
      selectedVersion = selectedVersion ?? manifest.stableVersion;
    } else {
      selectedVersion = manifest.betaVersion ?? manifest.stableVersion;
    }

    if (!selectedVersion) {
      const latest = await this.getLatestVersion(channel);
      if (!latest) {
        throw new Error(`Unable to resolve latest ${channel} runtime version`);
      }
      selectedVersion = latest;
      const resolved = await this.ensureInstalled(selectedVersion, channel);
      const health = await this.healthCheck(resolved);
      if (!health.ok) {
        throw new Error(`Initial runtime ${selectedVersion} failed health check: ${health.details ?? "unknown"}`);
      }
      if (channel === "stable") {
        manifest.stableVersion = selectedVersion;
      } else {
        manifest.betaVersion = selectedVersion;
      }
      manifest.lastUpdatedAt = new Date().toISOString();
      this.writeManifest(manifest);
      return resolved;
    }

    return await this.ensureInstalled(selectedVersion, channel);
  }

  async applyUpdate(
    channel: RuntimeChannel,
    targetVersion?: string,
    onProgress?: (progress: RuntimeUpdateProgress) => void,
    promoteToStable = true,
  ): Promise<ApplyRuntimeUpdateResponse> {
    const notify = (phase: RuntimeUpdateProgress["phase"], message: string) => {
      onProgress?.({ phase, message });
      log("info", `runtime update (${phase}): ${message}`);
    };

    notify("checking", `Checking ${channel} updates`);
    const manifest = this.readManifest();
    const previousVersion = channel === "stable" ? manifest.stableVersion : manifest.betaVersion;
    const latest = targetVersion ?? (await this.getLatestVersion(channel));

    if (!latest) {
      return {
        status: "failed",
        previousVersion,
        newVersion: null,
        health: { ok: false, details: "Could not resolve latest version from npm" },
      };
    }

    if (latest === previousVersion) {
      return {
        status: "already_latest",
        previousVersion,
        newVersion: previousVersion,
        health: { ok: true, details: "already on latest" },
      };
    }

    notify("downloading", `Installing runtime ${latest}`);
    try {
      const runtime = await this.ensureInstalled(latest, channel);
      notify("health_check", `Validating runtime ${latest}`);
      const health = await this.healthCheck(runtime);
      if (!health.ok) {
        notify("failed", `Health check failed for ${latest}`);
        return {
          status: "failed",
          previousVersion,
          newVersion: null,
          health,
        };
      }

      notify("promoting", `Promoting ${latest} to ${channel}`);
      if (channel === "stable") {
        manifest.stableVersion = latest;
      } else {
        manifest.betaVersion = latest;
        if (promoteToStable) {
          manifest.stableVersion = latest;
        }
      }
      manifest.lastUpdatedAt = new Date().toISOString();
      this.writeManifest(manifest);

      notify("done", `Runtime ${latest} is active`);
      return {
        status: "updated",
        previousVersion,
        newVersion: latest,
        health,
      };
    } catch (error) {
      const details = error instanceof Error ? error.message : String(error);
      notify("failed", details);
      return {
        status: "failed",
        previousVersion,
        newVersion: null,
        health: { ok: false, details },
      };
    }
  }
}
