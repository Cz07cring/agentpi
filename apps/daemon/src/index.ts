import { createDaemonApp } from "./app.js";

const daemon = createDaemonApp();

void daemon.listen();

let shuttingDown = false;
const shutdown = async () => {
  if (shuttingDown) return;
  shuttingDown = true;
  try {
    await daemon.shutdown();
  } catch {
    // Best-effort shutdown; exit regardless.
  }
  process.exit(0);
};

process.on("SIGINT", () => void shutdown());
process.on("SIGTERM", () => void shutdown());
