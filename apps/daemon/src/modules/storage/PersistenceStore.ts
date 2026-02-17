import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

export interface StoredSession {
  id: string;
  cwd: string;
  runtimeVersion: string;
  runtimeChannel: string;
  createdAt: string;
  lastStateJson: string;
}

export interface StoredWorkflow {
  id: string;
  graphJson: string;
  createdAt: string;
}

export interface StoredWorkflowRun {
  id: string;
  workflowId: string;
  stateJson: string;
  createdAt: string;
  updatedAt: string;
}

export interface StoredSessionRuntimeBinding {
  sessionId: string;
  runtimeSessionId: string | null;
  runtimeVersion: string;
  status: string;
  isStreaming: boolean;
  lastEventAt: string | null;
  updatedAt: string;
}

export interface CommandAuditLogEntry {
  actor: string;
  action: string;
  paramsJson: string;
  result: string;
  createdAt: string;
}

export class PersistenceStore {
  private readonly db: DatabaseSync;

  constructor(dbPath: string) {
    mkdirSync(dirname(dbPath), { recursive: true });
    this.db = new DatabaseSync(dbPath);
    this.migrate();
  }

  private migrate(): void {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        cwd TEXT NOT NULL,
        runtime_version TEXT NOT NULL,
        runtime_channel TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_state_json TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS workflows (
        id TEXT PRIMARY KEY,
        graph_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS workflow_runs (
        id TEXT PRIMARY KEY,
        workflow_id TEXT NOT NULL,
        state_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS session_runtime_bindings (
        session_id TEXT PRIMARY KEY,
        runtime_session_id TEXT,
        runtime_version TEXT NOT NULL,
        status TEXT NOT NULL,
        is_streaming INTEGER NOT NULL DEFAULT 0,
        last_event_at TEXT,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS search_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        text_value TEXT NOT NULL,
        file_path TEXT,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS command_audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        actor TEXT NOT NULL,
        action TEXT NOT NULL,
        params_json TEXT NOT NULL,
        result TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    `);
  }

  upsertSession(session: StoredSession): void {
    const statement = this.db.prepare(`
      INSERT INTO sessions (id, cwd, runtime_version, runtime_channel, created_at, last_state_json)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        cwd = excluded.cwd,
        runtime_version = excluded.runtime_version,
        runtime_channel = excluded.runtime_channel,
        last_state_json = excluded.last_state_json
    `);

    statement.run(
      session.id,
      session.cwd,
      session.runtimeVersion,
      session.runtimeChannel,
      session.createdAt,
      session.lastStateJson,
    );
  }

  getSession(id: string): StoredSession | null {
    const row = this.db
      .prepare(
        `SELECT id, cwd, runtime_version, runtime_channel, created_at, last_state_json
         FROM sessions WHERE id = ?`,
      )
      .get(id) as
      | {
          id: string;
          cwd: string;
          runtime_version: string;
          runtime_channel: string;
          created_at: string;
          last_state_json: string;
        }
      | undefined;

    if (!row) return null;
    return {
      id: row.id,
      cwd: row.cwd,
      runtimeVersion: row.runtime_version,
      runtimeChannel: row.runtime_channel,
      createdAt: row.created_at,
      lastStateJson: row.last_state_json,
    };
  }

  listSessions(): StoredSession[] {
    const rows = this.db
      .prepare(
        `SELECT id, cwd, runtime_version, runtime_channel, created_at, last_state_json
         FROM sessions ORDER BY created_at DESC`,
      )
      .all() as Array<{
      id: string;
      cwd: string;
      runtime_version: string;
      runtime_channel: string;
      created_at: string;
      last_state_json: string;
    }>;

    return rows.map((row) => ({
      id: row.id,
      cwd: row.cwd,
      runtimeVersion: row.runtime_version,
      runtimeChannel: row.runtime_channel,
      createdAt: row.created_at,
      lastStateJson: row.last_state_json,
    }));
  }

  insertWorkflow(workflow: StoredWorkflow): void {
    this.db
      .prepare(`INSERT INTO workflows (id, graph_json, created_at) VALUES (?, ?, ?)`)
      .run(workflow.id, workflow.graphJson, workflow.createdAt);
  }

  getWorkflow(id: string): StoredWorkflow | null {
    const row = this.db
      .prepare(`SELECT id, graph_json, created_at FROM workflows WHERE id = ?`)
      .get(id) as { id: string; graph_json: string; created_at: string } | undefined;

    if (!row) return null;
    return {
      id: row.id,
      graphJson: row.graph_json,
      createdAt: row.created_at,
    };
  }

  upsertWorkflowRun(run: StoredWorkflowRun): void {
    this.db
      .prepare(`
        INSERT INTO workflow_runs (id, workflow_id, state_json, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          state_json = excluded.state_json,
          updated_at = excluded.updated_at
      `)
      .run(run.id, run.workflowId, run.stateJson, run.createdAt, run.updatedAt);
  }

  getWorkflowRun(id: string): StoredWorkflowRun | null {
    const row = this.db
      .prepare(`SELECT id, workflow_id, state_json, created_at, updated_at FROM workflow_runs WHERE id = ?`)
      .get(id) as
      | {
          id: string;
          workflow_id: string;
          state_json: string;
          created_at: string;
          updated_at: string;
        }
      | undefined;

    if (!row) return null;
    return {
      id: row.id,
      workflowId: row.workflow_id,
      stateJson: row.state_json,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  upsertSessionRuntimeBinding(binding: StoredSessionRuntimeBinding): void {
    this.db
      .prepare(`
        INSERT INTO session_runtime_bindings (
          session_id,
          runtime_session_id,
          runtime_version,
          status,
          is_streaming,
          last_event_at,
          updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(session_id) DO UPDATE SET
          runtime_session_id = excluded.runtime_session_id,
          runtime_version = excluded.runtime_version,
          status = excluded.status,
          is_streaming = excluded.is_streaming,
          last_event_at = excluded.last_event_at,
          updated_at = excluded.updated_at
      `)
      .run(
        binding.sessionId,
        binding.runtimeSessionId,
        binding.runtimeVersion,
        binding.status,
        binding.isStreaming ? 1 : 0,
        binding.lastEventAt,
        binding.updatedAt,
      );
  }

  getSessionRuntimeBinding(sessionId: string): StoredSessionRuntimeBinding | null {
    const row = this.db
      .prepare(
        `SELECT session_id, runtime_session_id, runtime_version, status, is_streaming, last_event_at, updated_at
         FROM session_runtime_bindings WHERE session_id = ?`,
      )
      .get(sessionId) as
      | {
          session_id: string;
          runtime_session_id: string | null;
          runtime_version: string;
          status: string;
          is_streaming: number;
          last_event_at: string | null;
          updated_at: string;
        }
      | undefined;
    if (!row) return null;
    return {
      sessionId: row.session_id,
      runtimeSessionId: row.runtime_session_id,
      runtimeVersion: row.runtime_version,
      status: row.status,
      isStreaming: row.is_streaming === 1,
      lastEventAt: row.last_event_at,
      updatedAt: row.updated_at,
    };
  }

  indexSearchEntry(sessionId: string, textValue: string, filePath: string | null): void {
    this.db
      .prepare(`INSERT INTO search_entries (session_id, text_value, file_path, created_at) VALUES (?, ?, ?, ?)`)
      .run(sessionId, textValue, filePath, new Date().toISOString());
  }

  search(query: string, limit = 50): Array<{ sessionId: string; text: string; filePath: string | null }> {
    const normalized = `%${query.trim().toLowerCase()}%`;
    const rows = this.db
      .prepare(
        `SELECT session_id, text_value, file_path
         FROM search_entries
         WHERE lower(text_value) LIKE ?
         ORDER BY id DESC
         LIMIT ?`,
      )
      .all(normalized, limit) as Array<{ session_id: string; text_value: string; file_path: string | null }>;

    return rows.map((row) => ({
      sessionId: row.session_id,
      text: row.text_value,
      filePath: row.file_path,
    }));
  }

  insertAuditLog(entry: CommandAuditLogEntry): void {
    this.db
      .prepare(
        `INSERT INTO command_audit_logs (actor, action, params_json, result, created_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .run(entry.actor, entry.action, entry.paramsJson, entry.result, entry.createdAt);
  }
}
