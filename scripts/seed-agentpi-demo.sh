#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${1:-$ROOT_DIR}"
SESSION_ROOT="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
SESSIONS_DIR="$SESSION_ROOT/sessions"

mkdir -p "$SESSIONS_DIR"

SLUG="$(printf '%s' "$PROJECT_PATH" | sed 's#/#-#g')"
SESSION_DIR="$SESSIONS_DIR/-${SLUG}-"
mkdir -p "$SESSION_DIR"

SESSION_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
ENTRY_ID_1="$(uuidgen | cut -c1-8 | tr '[:upper:]' '[:lower:]')"
ENTRY_ID_2="$(uuidgen | cut -c1-8 | tr '[:upper:]' '[:lower:]')"
ENTRY_ID_3="$(uuidgen | cut -c1-8 | tr '[:upper:]' '[:lower:]')"

TS_NOW="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
FILE_TS="$(date -u +"%Y-%m-%dT%H-%M-%S-000Z")"
SESSION_FILE="$SESSION_DIR/${FILE_TS}_${SESSION_ID}.jsonl"
EPOCH_MS="$(($(date +%s) * 1000))"

cat > "$SESSION_FILE" <<JSONL
{"type":"session","version":3,"id":"$SESSION_ID","timestamp":"$TS_NOW","cwd":"$PROJECT_PATH"}
{"type":"model_change","id":"$ENTRY_ID_1","parentId":null,"timestamp":"$TS_NOW","provider":"openai","modelId":"gpt-5.1-codex"}
{"type":"message","id":"$ENTRY_ID_2","parentId":"$ENTRY_ID_1","timestamp":"$TS_NOW","message":{"role":"user","content":[{"type":"text","text":"Please summarize what this project does in one paragraph."}],"timestamp":$EPOCH_MS}}
{"type":"message","id":"$ENTRY_ID_3","parentId":"$ENTRY_ID_2","timestamp":"$TS_NOW","message":{"role":"assistant","content":[{"type":"thinking","thinking":"Scanning workspace and preparing a concise summary."},{"type":"text","text":"AgentPi is a local-first desktop orchestration tool that manages multiple coding sessions, monitors progress in real time, and supports workflow-driven task execution on top of pi-mono."}],"provider":"openai","model":"gpt-5.1-codex","usage":{"input":320,"output":62,"cacheRead":0,"cacheWrite":0,"totalTokens":382,"cost":{"input":0.0004,"output":0.0006,"cacheRead":0.0,"cacheWrite":0.0,"total":0.001}},"timestamp":$EPOCH_MS}}
JSONL

echo "Seeded demo session: $SESSION_FILE"
echo "Session root: $SESSION_ROOT"
echo "Project path: $PROJECT_PATH"
