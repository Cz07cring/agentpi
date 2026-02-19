import Foundation
import Testing
@testable import AgentPiCore

struct CodexSessionJSONLParserTests {
  @Test("tool call crosses timeout and becomes awaiting approval")
  func toolCallTransitionsToAwaitingApproval() {
    var result = CodexSessionJSONLParser.ParseResult()
    let line = assistantToolCallLine(
      timestamp: isoTimestamp(secondsAgo: 12),
      callId: "call-1",
      name: "edit",
      arguments: #"{"path":"/tmp/demo.swift","oldText":"old","newText":"new"}"#
    )

    CodexSessionJSONLParser.parseNewLines([line], into: &result, approvalTimeoutSeconds: 5)

    guard case .awaitingApproval(let tool) = result.currentStatus else {
      Issue.record("Expected awaitingApproval status, got \(result.currentStatus)")
      return
    }
    #expect(tool == "edit")
    #expect(result.pendingToolUses["call-1"]?.input == "demo.swift")
    #expect(result.pendingToolUses["call-1"]?.codeChangeInput?.toolType == .edit)
    #expect(result.pendingToolUses["call-1"]?.codeChangeInput?.filePath == "/tmp/demo.swift")
  }

  @Test("Task tool keeps executing and never flips to approval state")
  func taskToolRemainsExecuting() {
    var result = CodexSessionJSONLParser.ParseResult()
    let line = assistantToolCallLine(
      timestamp: isoTimestamp(secondsAgo: 30),
      callId: "task-1",
      name: "Task",
      arguments: #"{"command":"run background job"}"#
    )

    CodexSessionJSONLParser.parseNewLines([line], into: &result, approvalTimeoutSeconds: 5)

    guard case .executingTool(let tool) = result.currentStatus else {
      Issue.record("Expected executingTool status, got \(result.currentStatus)")
      return
    }
    #expect(tool == "Task")
  }

  @Test("tool result clears pending and moves to thinking")
  func toolResultClearsPending() {
    var result = CodexSessionJSONLParser.ParseResult()
    let callLine = assistantToolCallLine(
      timestamp: isoTimestamp(secondsAgo: 8),
      callId: "call-2",
      name: "bash",
      arguments: #"{"command":"ls"}"#
    )
    let resultLine = toolResultLine(
      timestamp: isoTimestamp(secondsAgo: 2),
      callId: "call-2",
      toolName: "bash"
    )

    CodexSessionJSONLParser.parseNewLines([callLine, resultLine], into: &result, approvalTimeoutSeconds: 5)

    #expect(result.pendingToolUses.isEmpty)
    #expect(result.currentStatus == .thinking)
  }

  @Test("response_item function_call participates in approval timeout")
  func responseItemFunctionCallSupportsApproval() {
    var result = CodexSessionJSONLParser.ParseResult()
    let line = """
    {"type":"response_item","timestamp":"\(isoTimestamp(secondsAgo: 11))","payload":{"type":"function_call","name":"bash","call_id":"fc-1","arguments":{"command":"git status"}}}
    """

    CodexSessionJSONLParser.parseNewLines([line], into: &result, approvalTimeoutSeconds: 5)

    guard case .awaitingApproval(let tool) = result.currentStatus else {
      Issue.record("Expected awaitingApproval status, got \(result.currentStatus)")
      return
    }
    #expect(tool == "bash")
    #expect(result.pendingToolUses["fc-1"]?.input == "git status")
  }

  private func assistantToolCallLine(
    timestamp: String,
    callId: String,
    name: String,
    arguments: String
  ) -> String {
    """
    {"type":"message","timestamp":"\(timestamp)","message":{"role":"assistant","content":[{"type":"toolCall","id":"\(callId)","name":"\(name)","arguments":\(arguments)}]}}
    """
  }

  private func toolResultLine(timestamp: String, callId: String, toolName: String) -> String {
    """
    {"type":"message","timestamp":"\(timestamp)","message":{"role":"toolResult","toolCallId":"\(callId)","toolName":"\(toolName)","content":[{"type":"text","text":"ok"}],"isError":false}}
    """
  }

  private func isoTimestamp(secondsAgo: TimeInterval) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date().addingTimeInterval(-secondsAgo))
  }
}
