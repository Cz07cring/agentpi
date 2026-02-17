import { createDaemonApp } from "./app.js";

const daemon = createDaemonApp();

void daemon.listen();

const shutdown = async () => {
  await daemon.shutdown();
  process.exit(0);
};

process.on("SIGINT", () => void shutdown());
process.on("SIGTERM", () => void shutdown());
