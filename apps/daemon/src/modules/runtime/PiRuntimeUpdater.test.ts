import { describe, expect, it } from "vitest";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { CommandRunner, RunCommandOptions, RunCommandResult } from "../../lib/command-runner.js";
import { PiRuntimeUpdater } from "./PiRuntimeUpdater.js";

class FakeRunner implements CommandRunner {
  calls: Array<{ command: string; args: string[]; options?: RunCommandOptions }> = [];

  async run(command: string, args: string[], options?: RunCommandOptions): Promise<RunCommandResult> {
    this.calls.push({ command, args, options });

    if (args.includes("dist-tags.beta")) {
      return { code: 0, stdout: "0.52.12-beta.1\n", stderr: "" };
    }

    if (args.includes("version")) {
      return { code: 0, stdout: "0.52.12\n", stderr: "" };
    }

    if (args[0] === "install") {
      return { code: 0, stdout: "installed\n", stderr: "" };
    }

    return { code: 0, stdout: "\n", stderr: "" };
  }
}

describe("PiRuntimeUpdater", () => {
  it("checks latest runtime version", async () => {
    const dir = mkdtempSync(join(tmpdir(), "agentpi-runtime-test-"));
    const runner = new FakeRunner();

    const updater = new PiRuntimeUpdater({
      baseDir: join(dir, "runtimes", "pi"),
      manifestPath: join(dir, "runtime-manifest.json"),
      runner,
    });

    const result = await updater.checkForUpdate("stable");
    expect(result.latestVersion).toBe("0.52.12");
    expect(result.channel).toBe("stable");
  });
});
