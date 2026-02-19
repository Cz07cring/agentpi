# UX Regression Checklist

Focused manual regression checklist for AgentPi UX flows, with emphasis on image paste/drag and session approval paths.

## Preconditions
- App built and launched.
- Daemon running on localhost.
- At least one repository added to the Hub.
- A test Claude/Codex/AgentPi session available.

## A. Embedded Terminal Paste
- [ ] **Paste screenshot image**
  - Steps: Capture screenshot (Shift+Cmd+4) → focus embedded terminal → Cmd+V.
  - Expected: Inserts a `.png` temp file path, with a trailing space. No errors in UI.
- [ ] **Paste file URL**
  - Steps: Copy a file from Finder → Cmd+V in terminal.
  - Expected: File path inserted. If path contains spaces, it is quoted.
- [ ] **Paste plain text**
  - Steps: Copy plain text → Cmd+V.
  - Expected: Text paste behavior unchanged.

## B. Monitoring Card Drag & Drop
- [ ] **Drag PNG/TIFF/HEIC into monitoring card**
  - Steps: Drag image into monitoring card terminal.
  - Expected: A `.png` temp file path is inserted and readable by CLI.
- [ ] **Drag PDF**
  - Steps: Drag a PDF into monitoring card terminal.
  - Expected: PDF path inserted and readable.

## C. Multi-Session Launch Attachments
- [ ] **Drag PNG/TIFF/HEIC into launcher**
  - Steps: Drag image into launcher attachments area.
  - Expected: Attachment appears and opens; file stored as temp `.png`.
- [ ] **Remove attachment**
  - Steps: Remove the attachment from UI.
  - Expected: Temp file is deleted.

## D. Approval Actions (Cross-Provider)
- [ ] **Claude approval**
  - Steps: Trigger approval → click Approve/Reject.
  - Expected: Terminal receives `1` (approve) / `3` (reject).
- [ ] **Codex/AgentPi approval**
  - Steps: Trigger approval → click Approve/Reject.
  - Expected: Terminal receives `y` (approve) / `n` (reject).

## E. New Session Fallback
- [ ] **History delay fallback**
  - Steps: Start a new session in a worktree while history.jsonl is still updating.
  - Expected: New session appears without requiring the worktree to be empty.
