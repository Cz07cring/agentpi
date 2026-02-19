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

async function httpPost(port: number, path: string, body: unknown, token?: string): Promise<Response> {
  return await fetch(`http://127.0.0.1:${port}${path}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { "x-agentpi-token": token } : {}),
    },
    body: JSON.stringify(body),
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

  it("rejects session creation with invalid cwd", async () => {
    const started = await startDaemon();
    running.push(started.daemon);

    const res = await httpPost(started.port, "/v1/sessions", { cwd: "/path/not/exist" }, started.token);
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string; code?: string };
    expect(body.code).toBe("invalid_cwd");
  });

  it("rejects worktree removal with invalid id", async () => {
    const started = await startDaemon();
    running.push(started.daemon);

    const res = await fetch(`http://127.0.0.1:${started.port}/v1/worktrees/not-base64`, {
      method: "DELETE",
      headers: { "x-agentpi-token": started.token },
    });

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string; code?: string };
    expect(body.code).toBe("invalid_worktree_id");
  });

  it("rejects worktree removal when path is not a git worktree", async () => {
    const started = await startDaemon();
    running.push(started.daemon);

    const fakePath = Buffer.from("/tmp", "utf8").toString("base64url");
    const res = await fetch(`http://127.0.0.1:${started.port}/v1/worktrees/${fakePath}`, {
      method: "DELETE",
      headers: { "x-agentpi-token": started.token },
    });

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string; code?: string };
    expect(body.code).toBe("not_a_git_worktree");
  });
});
