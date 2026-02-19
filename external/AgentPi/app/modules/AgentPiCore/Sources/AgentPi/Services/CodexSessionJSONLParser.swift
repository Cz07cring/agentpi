//
//  CodexSessionJSONLParser.swift
//  AgentPi
//
//  Parser for Codex session JSONL files with minimal monitoring data.
//

import Foundation

public struct CodexSessionJSONLParser {

  // MARK: - Lightweight Parse Result for Global Stats

  /// Minimal parsing result containing only fields needed for global stats aggregation.
  /// Significantly reduces memory overhead by skipping activities, tool calls, timestamps, and status.
  public struct GlobalStatsParseResult {
    public var model: String?
    public var totalInputTokens: Int = 0
    public var totalOutputTokens: Int = 0
    public var cacheReadTokens: Int = 0
    public var messageCount: Int = 0

    public init() {}
  }

  // MARK: - Parsing Results

  public struct ParseResult {
    public var model: String?
    public var lastInputTokens: Int = 0
    public var lastOutputTokens: Int = 0
    public var totalInputTokens: Int = 0  // Cumulative input tokens from total_token_usage
    public var totalOutputTokens: Int = 0
    public var cacheReadTokens: Int = 0
    public var cacheCreationTokens: Int = 0
    public var messageCount: Int = 0
    public var firstMessage: String?
    public var lastMessage: String?
    public var toolCalls: [String: Int] = [:]
    public var pendingToolUses: [String: PendingToolInfo] = [:]
    public var recentActivities: [ActivityEntry] = []
    public var lastActivityAt: Date?
    public var sessionStartedAt: Date?
    public var currentStatus: SessionStatus = .idle

    public init() {}
  }

  public struct PendingToolInfo {
    public let toolName: String
    public let toolUseId: String
    public let timestamp: Date
    public let input: String?
    public let codeChangeInput: CodeChangeInput?
  }

  // MARK: - Public API

  /// Lightweight parsing for global stats aggregation.
  /// Skips activity tracking, tool call tracking, timestamp parsing, and status computation.
  /// Memory efficient: only extracts model, tokens, and message count.
  public static func parseForGlobalStats(at path: String) -> GlobalStatsParseResult {
    var result = GlobalStatsParseResult()

    guard let handle = FileHandle(forReadingAtPath: path) else {
      return result
    }
    defer { try? handle.close() }

    guard let data = try? handle.readToEnd(),
          let content = String(data: data, encoding: .utf8) else {
      return result
    }

    for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
      guard let lineData = line.data(using: .utf8),
            let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
            let type = entry["type"] as? String else { continue }

      switch type {
      case "turn_context":
        if let payload = entry["payload"] as? [String: Any],
           let model = payload["model"] as? String {
          result.model = model
        }
      case "model_change":
        if let model = entry["modelId"] as? String ?? entry["model"] as? String {
          result.model = model
        }

      case "event_msg":
        guard let payload = entry["payload"] as? [String: Any],
              let eventType = payload["type"] as? String else { continue }

        if eventType == "user_message" || eventType == "agent_message" {
          result.messageCount += 1
        } else if eventType == "token_count",
                  let info = payload["info"] as? [String: Any],
                  let total = info["total_token_usage"] as? [String: Any] {
          let input = (total["input_tokens"] as? Int) ?? 0
          let cached = (total["cached_input_tokens"] as? Int) ?? 0
          let output = (total["output_tokens"] as? Int) ?? 0
          result.totalInputTokens = input + cached
          result.totalOutputTokens = output
          result.cacheReadTokens = cached
        }

      case "message":
        guard let payload = entry["message"] as? [String: Any],
              let role = payload["role"] as? String else { continue }

        if role == "user" || role == "assistant" {
          result.messageCount += 1
        }

        if role == "assistant",
           let usage = payload["usage"] as? [String: Any] {
          let input = (usage["input"] as? Int) ?? 0
          let output = (usage["output"] as? Int) ?? 0
          let cacheRead = (usage["cacheRead"] as? Int) ?? 0
          // pi usage is per message; aggregate totals here.
          result.totalInputTokens += input + cacheRead
          result.totalOutputTokens += output
          result.cacheReadTokens += cacheRead
        }

      default:
        break
      }
    }

    return result
  }

  public static func parseSessionFile(at path: String, approvalTimeoutSeconds: Int = 0) -> ParseResult {
    var result = ParseResult()

    guard let data = FileManager.default.contents(atPath: path),
          let content = String(data: data, encoding: .utf8) else {
      return result
    }

    for line in content.components(separatedBy: .newlines) where !line.isEmpty {
      if let entry = parseEntry(line) {
        processEntry(entry, into: &result)
      }
    }

    updateCurrentStatus(&result, approvalTimeoutSeconds: approvalTimeoutSeconds)
    return result
  }

  public static func parseNewLines(_ lines: [String], into result: inout ParseResult, approvalTimeoutSeconds: Int = 0) {
    for line in lines where !line.isEmpty {
      if let entry = parseEntry(line) {
        processEntry(entry, into: &result)
      }
    }
    updateCurrentStatus(&result, approvalTimeoutSeconds: approvalTimeoutSeconds)
  }

  // MARK: - Parsing

  private static func parseEntry(_ line: String) -> [String: Any]? {
    guard let data = line.data(using: .utf8) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  private static func processEntry(_ entry: [String: Any], into result: inout ParseResult) {
    guard let type = entry["type"] as? String else { return }
    let timestamp = parseTimestamp(entry["timestamp"] as? String)

    if let ts = timestamp {
      if result.sessionStartedAt == nil {
        result.sessionStartedAt = ts
      }
      result.lastActivityAt = ts
    }

    switch type {
    case "session":
      if let tsString = entry["timestamp"] as? String,
         result.sessionStartedAt == nil {
        result.sessionStartedAt = parseTimestamp(tsString)
      }

    case "session_meta":
      if let payload = entry["payload"] as? [String: Any],
         let tsString = payload["timestamp"] as? String {
        if result.sessionStartedAt == nil {
          result.sessionStartedAt = parseTimestamp(tsString)
        }
      }

    case "turn_context":
      if let payload = entry["payload"] as? [String: Any],
         let model = payload["model"] as? String {
        result.model = model
      }

    case "model_change":
      if let model = entry["modelId"] as? String ?? entry["model"] as? String {
        result.model = model
      }

    case "event_msg":
      guard let payload = entry["payload"] as? [String: Any],
            let eventType = payload["type"] as? String else { return }
      handleEventMessage(type: eventType, payload: payload, timestamp: timestamp, result: &result)

    case "response_item":
      guard let payload = entry["payload"] as? [String: Any],
            let payloadType = payload["type"] as? String else { return }
      handleResponseItem(type: payloadType, payload: payload, timestamp: timestamp, result: &result)

    case "message":
      guard let payload = entry["message"] as? [String: Any] else { return }
      handlePiMessage(payload: payload, timestamp: timestamp, result: &result)

    default:
      break
    }
  }

  private static func handleEventMessage(
    type: String,
    payload: [String: Any],
    timestamp: Date?,
    result: inout ParseResult
  ) {
    switch type {
    case "user_message":
      result.messageCount += 1
      if let message = payload["message"] as? String, !message.isEmpty {
        recordMessagePreview(message, in: &result)
        addActivity(type: .userMessage, description: String(message.prefix(80)), timestamp: timestamp, to: &result)
      }

    case "agent_message":
      result.messageCount += 1
      if let message = payload["message"] as? String, !message.isEmpty {
        recordMessagePreview(message, in: &result)
        addActivity(type: .assistantMessage, description: String(message.prefix(80)), timestamp: timestamp, to: &result)
      }

    case "agent_reasoning":
      addActivity(type: .thinking, description: "Thinking...", timestamp: timestamp, to: &result)

    case "token_count":
      guard let info = payload["info"] as? [String: Any] else { return }
      // Use total_token_usage for cumulative session totals (used by global stats)
      if let total = info["total_token_usage"] as? [String: Any] {
        let input = (total["input_tokens"] as? Int) ?? 0
        let cached = (total["cached_input_tokens"] as? Int) ?? 0
        let output = (total["output_tokens"] as? Int) ?? 0
        // Store the latest totals (the API accumulates these values)
        result.totalInputTokens = input + cached
        result.totalOutputTokens = output
        result.cacheReadTokens = cached
      }
      // Use last_token_usage for real-time monitoring
      if let last = info["last_token_usage"] as? [String: Any] {
        let input = (last["input_tokens"] as? Int) ?? 0
        let cached = (last["cached_input_tokens"] as? Int) ?? 0
        let output = (last["output_tokens"] as? Int) ?? 0
        result.lastInputTokens = input + cached
        result.lastOutputTokens = output
      }

    default:
      break
    }
  }

  private static func handleResponseItem(
    type: String,
    payload: [String: Any],
    timestamp: Date?,
    result: inout ParseResult
  ) {
    switch type {
    case "function_call":
      guard let name = payload["name"] as? String,
            let callId = payload["call_id"] as? String else { return }
      let toolInput = payload["arguments"] ?? payload["input"]
      let inputPreview = extractInputPreview(toolInput)
      let codeChangeInput = extractCodeChangeInput(name: name, input: toolInput)
      result.toolCalls[name, default: 0] += 1
      result.pendingToolUses[callId] = PendingToolInfo(
        toolName: name,
        toolUseId: callId,
        timestamp: timestamp ?? Date(),
        input: inputPreview,
        codeChangeInput: codeChangeInput
      )
      addActivity(
        type: .toolUse(name: name),
        description: inputPreview ?? name,
        timestamp: timestamp,
        codeChangeInput: codeChangeInput,
        to: &result
      )

    case "function_call_output":
      if let callId = payload["call_id"] as? String {
        let toolName = result.pendingToolUses[callId]?.toolName ?? "tool"
        result.pendingToolUses.removeValue(forKey: callId)
        addActivity(type: .toolResult(name: toolName, success: true), description: "Completed", timestamp: timestamp, to: &result)
      }

    case "custom_tool_call":
      guard let name = payload["name"] as? String else { return }
      let status = (payload["status"] as? String ?? "").lowercased()
      let callId = payload["call_id"] as? String
        ?? payload["id"] as? String
        ?? UUID().uuidString
      let toolInput = payload["arguments"] ?? payload["input"]
      let inputPreview = extractInputPreview(toolInput)
      let codeChangeInput = extractCodeChangeInput(name: name, input: toolInput)
      let isCompleted = status == "completed" || status == "success" || status == "succeeded"
      let isFailed = status == "failed" || status == "error"

      if isCompleted || isFailed {
        result.pendingToolUses.removeValue(forKey: callId)
        addActivity(
          type: .toolResult(name: name, success: !isFailed),
          description: isFailed ? "Failed" : "Completed",
          timestamp: timestamp,
          to: &result
        )
      } else {
        let isNewCall = result.pendingToolUses[callId] == nil
        if isNewCall {
          result.toolCalls[name, default: 0] += 1
          addActivity(
            type: .toolUse(name: name),
            description: inputPreview ?? name,
            timestamp: timestamp,
            codeChangeInput: codeChangeInput,
            to: &result
          )
        }
        result.pendingToolUses[callId] = PendingToolInfo(
          toolName: name,
          toolUseId: callId,
          timestamp: timestamp ?? Date(),
          input: inputPreview,
          codeChangeInput: codeChangeInput
        )
      }

    default:
      break
    }
  }

  private static func handlePiMessage(
    payload: [String: Any],
    timestamp: Date?,
    result: inout ParseResult
  ) {
    guard let role = payload["role"] as? String else { return }
    let content = payload["content"] as? [[String: Any]] ?? []

    switch role {
    case "user":
      result.messageCount += 1
      if let text = extractFirstText(from: content), !text.isEmpty {
        recordMessagePreview(text, in: &result)
        addActivity(type: .userMessage, description: String(text.prefix(80)), timestamp: timestamp, to: &result)
      }

    case "assistant":
      result.messageCount += 1

      if let usage = payload["usage"] as? [String: Any] {
        let input = (usage["input"] as? Int) ?? 0
        let output = (usage["output"] as? Int) ?? 0
        let cacheRead = (usage["cacheRead"] as? Int) ?? 0
        result.lastInputTokens = input + cacheRead
        result.lastOutputTokens = output
        result.totalInputTokens += input + cacheRead
        result.totalOutputTokens += output
        result.cacheReadTokens += cacheRead
      }

      var emittedAssistantText = false
      for item in content {
        guard let itemType = item["type"] as? String else { continue }
        switch itemType {
        case "toolCall":
          let name = item["name"] as? String ?? "tool"
          let callId = item["id"] as? String ?? UUID().uuidString
          let toolInput = item["arguments"] ?? item["input"]
          let inputPreview = extractInputPreview(toolInput)
          let codeChangeInput = extractCodeChangeInput(name: name, input: toolInput)
          result.toolCalls[name, default: 0] += 1
          result.pendingToolUses[callId] = PendingToolInfo(
            toolName: name,
            toolUseId: callId,
            timestamp: timestamp ?? Date(),
            input: inputPreview,
            codeChangeInput: codeChangeInput
          )
          addActivity(
            type: .toolUse(name: name),
            description: inputPreview ?? name,
            timestamp: timestamp,
            codeChangeInput: codeChangeInput,
            to: &result
          )

        case "thinking":
          addActivity(type: .thinking, description: "Thinking...", timestamp: timestamp, to: &result)

        case "text":
          if !emittedAssistantText,
             let text = item["text"] as? String,
             !text.isEmpty {
            emittedAssistantText = true
            recordMessagePreview(text, in: &result)
            addActivity(type: .assistantMessage, description: String(text.prefix(80)), timestamp: timestamp, to: &result)
          }

        default:
          continue
        }
      }

    case "toolResult":
      let callId = payload["toolCallId"] as? String
      let pendingToolName = callId.flatMap { result.pendingToolUses[$0]?.toolName }
      if let callId {
        result.pendingToolUses.removeValue(forKey: callId)
      }
      let toolName = payload["toolName"] as? String
        ?? payload["name"] as? String
        ?? pendingToolName
        ?? "tool"
      let isError = payload["isError"] as? Bool ?? false
      addActivity(type: .toolResult(name: toolName, success: !isError), description: isError ? "Failed" : "Completed", timestamp: timestamp, to: &result)

    default:
      break
    }
  }

  // MARK: - Status

  public static func updateCurrentStatus(_ result: inout ParseResult, approvalTimeoutSeconds: Int = 0) {
    // Pending tool uses are the strongest signal of "still waiting", including approval flows.
    if let pending = latestPendingToolUse(from: result) {
      let pendingDuration = Date().timeIntervalSince(pending.timestamp)
      let timeout = Double(max(1, approvalTimeoutSeconds))

      if isBackgroundTool(name: pending.toolName) {
        result.currentStatus = .executingTool(name: pending.toolName)
      } else if pendingDuration > timeout {
        result.currentStatus = .awaitingApproval(tool: pending.toolName)
      } else {
        result.currentStatus = .executingTool(name: pending.toolName)
      }
      return
    }

    guard let lastActivity = result.recentActivities.last else {
      result.currentStatus = .idle
      return
    }

    let timeSince = Date().timeIntervalSince(lastActivity.timestamp)

    if timeSince > 300 {
      result.currentStatus = .idle
      return
    }

    switch lastActivity.type {
    case .toolUse(let name):
      result.currentStatus = .executingTool(name: name)
    case .toolResult:
      result.currentStatus = timeSince < 60 ? .thinking : .idle
    case .assistantMessage:
      result.currentStatus = .waitingForUser
    case .userMessage:
      result.currentStatus = timeSince < 60 ? .thinking : .idle
    case .thinking:
      result.currentStatus = timeSince < 30 ? .thinking : .idle
    }
  }

  // MARK: - Helpers

  private static func addActivity(
    type: ActivityType,
    description: String,
    timestamp: Date?,
    codeChangeInput: CodeChangeInput? = nil,
    to result: inout ParseResult
  ) {
    let entry = ActivityEntry(
      timestamp: timestamp ?? Date(),
      type: type,
      description: description,
      toolInput: codeChangeInput
    )
    result.recentActivities.append(entry)

    if result.recentActivities.count > 100 {
      result.recentActivities.removeFirst(result.recentActivities.count - 100)
    }
  }

  private static func extractFirstText(from content: [[String: Any]]) -> String? {
    for item in content {
      guard let type = item["type"] as? String, type == "text",
            let text = item["text"] as? String, !text.isEmpty else {
        continue
      }
      return text
    }
    return nil
  }

  private static func recordMessagePreview(_ text: String, in result: inout ParseResult) {
    if result.firstMessage == nil {
      result.firstMessage = text
    }
    result.lastMessage = text
  }

  private static func latestPendingToolUse(from result: ParseResult) -> PendingToolInfo? {
    result.pendingToolUses.values.max { $0.timestamp < $1.timestamp }
  }

  private static func isBackgroundTool(name: String) -> Bool {
    name.caseInsensitiveCompare("Task") == .orderedSame
  }

  private static func extractInputPreview(_ input: Any?) -> String? {
    guard let dict = normalizeDictionary(input) else { return nil }

    if let path = dict["file_path"] as? String ?? dict["path"] as? String {
      return URL(fileURLWithPath: path).lastPathComponent
    }
    if let command = dict["command"] as? String {
      return String(command.prefix(80))
    }
    if let query = dict["query"] as? String {
      return String(query.prefix(80))
    }
    if let pattern = dict["pattern"] as? String {
      return String(pattern.prefix(80))
    }

    return nil
  }

  private static func extractCodeChangeInput(name: String, input: Any?) -> CodeChangeInput? {
    guard let dict = normalizeDictionary(input),
          let filePath = dict["file_path"] as? String ?? dict["path"] as? String else {
      return nil
    }

    switch name.lowercased() {
    case "edit":
      return CodeChangeInput(
        toolType: .edit,
        filePath: filePath,
        oldString: dict["old_string"] as? String ?? dict["oldText"] as? String,
        newString: dict["new_string"] as? String ?? dict["newText"] as? String,
        replaceAll: dict["replace_all"] as? Bool ?? dict["replaceAll"] as? Bool
      )

    case "write":
      return CodeChangeInput(
        toolType: .write,
        filePath: filePath,
        newString: dict["content"] as? String ?? dict["newText"] as? String
      )

    case "multiedit":
      let rawEdits = dict["edits"] as? [[String: Any]]
      let edits = rawEdits?.compactMap { edit -> [String: String]? in
        var normalized: [String: String] = [:]
        if let old = edit["old_string"] as? String ?? edit["oldText"] as? String {
          normalized["old_string"] = old
        }
        if let new = edit["new_string"] as? String ?? edit["newText"] as? String {
          normalized["new_string"] = new
        }
        if let replace = edit["replace_all"] as? Bool ?? edit["replaceAll"] as? Bool {
          normalized["replace_all"] = String(replace)
        }
        return normalized.isEmpty ? nil : normalized
      }
      return CodeChangeInput(
        toolType: .multiEdit,
        filePath: filePath,
        edits: edits
      )

    default:
      return nil
    }
  }

  private static func normalizeDictionary(_ input: Any?) -> [String: Any]? {
    if let dict = input as? [String: Any] {
      return dict
    }
    if let json = input as? String,
       let data = json.data(using: .utf8),
       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      return dict
    }
    return nil
  }

  private static func parseTimestamp(_ string: String?) -> Date? {
    guard let string else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: string) {
      return date
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: string)
  }
}
