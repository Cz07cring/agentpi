import { afterEach, describe, expect, it } from "vitest";
import { randomUUID } from "node:crypto";
import { WebSocket } from "ws";
import { createDaemonApp, type DaemonApp } from "./app.js";

interface StartedDaemon {
  daemon: DaemonApp;
  port: number;
  token: string;
}

async function startDaemon(): Promise<StartedDaemon> {
  const token = `test-token-${randomUUID()}`;
  process.env.AGENTPI_DAEMON_TOKEN = token;
  const daemon = createDaemonApp();
  const { port } = await daemon.listen(0);
  return { daemon, port, token };
}

async function httpGet(port: number, path: string, token?: string): Promise<Response> {
  return await fetch(`http://127.0.0.1:${port}${path}`, {
    headers: token
      ? {
          "x-agentpi-token": token,
        }
      : undefined,
  });
}

describe("daemon API contract", () => {
  const running: DaemonApp[] = [];

  afterEach(async () => {
    while (running.length > 0) {
      const daemon = running.pop();
      if (daemon) {
        await daemon.shutdown();
      }
    }
    delete process.env.AGENTPI_DAEMON_TOKEN;
  });

  it("keeps /health public but protects /health/details with token", async () => {
    const started = await startDaemon();
    running.push(started.daemon);

    const health = await httpGet(started.port, "/health");
    expect(health.status).toBe(200);

    const detailsNoToken = await httpGet(started.port, "/health/details");
    expect(detailsNoToken.status).toBe(401);

    const detailsWithToken = await httpGet(started.port, "/health/details", started.token);
    expect(detailsWithToken.status).toBe(200);

    const detailsJson = (await detailsWithToken.json()) as {
      auth: { tokenRequired: boolean; mode: string };
      daemon: { pid: number; startedAt: string };
      ws: { currentConnections: number; acceptedConnections: number; rejectedConnections: number };
      http: { port: number | null };
    };

    expect(detailsJson.auth.tokenRequired).toBe(true);
    expect(detailsJson.auth.mode).toBe("local-token");
    expect(detailsJson.daemon.pid).toBeGreaterThan(0);
    expect(detailsJson.daemon.startedAt).toMatch(/T/);
    expect(detailsJson.http.port).toBe(started.port);
    expect(detailsJson.ws.currentConnections).toBeGreaterThanOrEqual(0);
  });

  it("tracks rejected websocket handshakes in health details", async () => {
    const started = await startDaemon();
    running.push(started.daemon);

    await new Promise<void>((resolve) => {
      const ws = new WebSocket(`ws://127.0.0.1:${started.port}/ws?token=wrong-token`);
      ws.on("error", () => {
        resolve();
      });
      ws.on("close", () => {
        resolve();
      });
    });

    const detailsWithToken = await httpGet(started.port, "/health/details", started.token);
    const detailsJson = (await detailsWithToken.json()) as {
      ws: { rejectedConnections: number };
    };

    expect(detailsJson.ws.rejectedConnections).toBeGreaterThanOrEqual(1);
  });
});
