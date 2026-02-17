import { execSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Socket } from "node:net";
import { existsSync } from "node:fs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, "..");

const daemonPort = Number(process.env.AGENTPI_DAEMON_PORT ?? 43210);
const token = process.env.AGENTPI_DAEMON_TOKEN ?? "";
const now = new Date().toISOString();

const workspacePath = join(rootDir, "external", "AgentPi", "app", "AgentPi.xcodeproj", "project.xcworkspace");
const appPath = join(rootDir, ".build-macos", "DerivedData", "Build", "Products", "Debug", "AgentPi.app");

function commandAvailable(command) {
  try {
    execSync(`command -v ${command}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function checkTcpPort(host, port, timeoutMs = 650) {
  return new Promise((resolve) => {
    const socket = new Socket();
    let settled = false;

    const done = (ok) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(ok);
    };

    socket.setTimeout(timeoutMs);
    socket.once("connect", () => done(true));
    socket.once("timeout", () => done(false));
    socket.once("error", () => done(false));
    socket.connect(port, host);
  });
}

async function main() {
  const xcodebuildAvailable = commandAvailable("xcodebuild");
  const daemonListening = await checkTcpPort("127.0.0.1", daemonPort);

  const diagnostics = [
    ["time", now],
    ["xcodebuild", xcodebuildAvailable ? "found" : "missing"],
    ["workspaceExists", existsSync(workspacePath) ? "yes" : "no"],
    ["workspacePath", workspacePath],
    ["appBuilt", existsSync(appPath) ? "yes" : "no"],
    ["appPath", appPath],
    ["daemonPort", String(daemonPort)],
    ["daemonPortListening", daemonListening ? "yes" : "no"],
    ["tokenInCurrentShell", token.length > 0 ? "present" : "missing"],
  ];

  console.log("AgentPi dev doctor");
  console.log("==================");
  for (const [key, value] of diagnostics) {
    console.log(`${key}: ${value}`);
  }

  if (!xcodebuildAvailable || !existsSync(workspacePath)) {
    process.exitCode = 1;
  }
}

void main();
