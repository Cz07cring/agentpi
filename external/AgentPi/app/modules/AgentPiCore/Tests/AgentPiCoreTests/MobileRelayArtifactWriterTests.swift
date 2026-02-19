import Foundation
import Testing
@testable import AgentPiCore

@Suite(.serialized)
struct MobileRelayArtifactWriterTests {
  @Test("writer creates jsonl and markdown handoff artifacts")
  func writerCreatesDualArtifacts() throws {
    let writer = MobileRelayArtifactWriter()
    let projectPath = FileManager.default.temporaryDirectory
      .appendingPathComponent("agentpi-mobile-relay-\(UUID().uuidString)")
      .path
    try FileManager.default.createDirectory(
      at: URL(fileURLWithPath: projectPath),
      withIntermediateDirectories: true
    )

    defer {
      try? FileManager.default.removeItem(atPath: projectPath)
    }

    let session = CLISession(
      id: "session-12345678",
      projectPath: projectPath,
      branchName: "main",
      firstMessage: "ship handoff",
      lastMessage: "latest handoff prompt"
    )
    let createdAt = Date()
    let paths = try writer.createPaths(projectPath: projectPath, sessionShortId: "12345678", at: createdAt)
    try writer.writeArtifacts(
      paths: paths,
      payload: MobileRelayArtifactPayload(
        session: session,
        sourceProvider: .claude,
        targetProvider: .codex,
        initialPrompt: "latest handoff prompt",
        note: "handoff note",
        commandLine: "happy codex --handoff \(paths.jsonlPath)",
        createdAt: createdAt
      )
    )

    #expect(FileManager.default.fileExists(atPath: paths.jsonlPath))
    #expect(FileManager.default.fileExists(atPath: paths.markdownPath))

    let jsonl = try String(contentsOfFile: paths.jsonlPath, encoding: .utf8)
    let markdown = try String(contentsOfFile: paths.markdownPath, encoding: .utf8)
    #expect(jsonl.contains("\"sessionId\":\"session-12345678\""))
    #expect(markdown.contains("# AgentPi Mobile Relay Handoff"))
    #expect(markdown.contains("latest handoff prompt"))
  }
}
