//
//  MobileRelayArtifactWriter.swift
//  AgentPi
//
//  Writes project-local JSONL + Markdown handoff artifacts.
//

import Foundation

public struct MobileRelayArtifactPaths: Sendable {
  public let directoryPath: String
  public let jsonlPath: String
  public let markdownPath: String
}

public struct MobileRelayArtifactPayload: Sendable {
  public let session: CLISession
  public let sourceProvider: SessionProviderKind
  public let targetProvider: SessionProviderKind
  public let initialPrompt: String?
  public let note: String?
  public let commandLine: String
  public let createdAt: Date
}

public struct MobileRelayArtifactWriter {
  public init() {}

  public func createPaths(
    projectPath: String,
    sessionShortId: String,
    at date: Date = Date()
  ) throws -> MobileRelayArtifactPaths {
    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "yyyy-MM-dd"
    dayFormatter.locale = Locale(identifier: "en_US_POSIX")
    dayFormatter.timeZone = TimeZone.current

    let timestampFormatter = DateFormatter()
    timestampFormatter.dateFormat = "yyyyMMdd-HHmmss"
    timestampFormatter.locale = Locale(identifier: "en_US_POSIX")
    timestampFormatter.timeZone = TimeZone.current

    let dayFolder = dayFormatter.string(from: date)
    let timestamp = timestampFormatter.string(from: date)
    let baseDirectory = URL(fileURLWithPath: projectPath)
      .appendingPathComponent(".agentpi")
      .appendingPathComponent("mobile-relay")
      .appendingPathComponent(dayFolder)

    try FileManager.default.createDirectory(
      at: baseDirectory,
      withIntermediateDirectories: true,
      attributes: nil
    )

    let baseName = "\(timestamp)-\(sessionShortId)"
    let jsonlPath = baseDirectory.appendingPathComponent("\(baseName).jsonl").path
    let markdownPath = baseDirectory.appendingPathComponent("\(baseName).md").path

    return MobileRelayArtifactPaths(
      directoryPath: baseDirectory.path,
      jsonlPath: jsonlPath,
      markdownPath: markdownPath
    )
  }

  public func writeArtifacts(
    paths: MobileRelayArtifactPaths,
    payload: MobileRelayArtifactPayload
  ) throws {
    let jsonLine = try buildJSONLine(payload: payload)
    try (jsonLine + "\n").write(toFile: paths.jsonlPath, atomically: true, encoding: .utf8)

    let markdown = buildMarkdown(paths: paths, payload: payload)
    try markdown.write(toFile: paths.markdownPath, atomically: true, encoding: .utf8)
  }

  private func buildJSONLine(payload: MobileRelayArtifactPayload) throws -> String {
    let object: [String: Any] = [
      "sessionId": payload.session.id,
      "sourceProvider": payload.sourceProvider.stableKey,
      "targetProvider": payload.targetProvider.stableKey,
      "projectPath": payload.session.projectPath,
      "initialPrompt": payload.initialPrompt ?? "",
      "createdAt": ISO8601DateFormatter().string(from: payload.createdAt)
    ]
    let data = try JSONSerialization.data(withJSONObject: object, options: [])
    guard let json = String(data: data, encoding: .utf8) else {
      throw NSError(
        domain: "MobileRelayArtifactWriter",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSONL line."]
      )
    }
    return json
  }

  private func buildMarkdown(
    paths: MobileRelayArtifactPaths,
    payload: MobileRelayArtifactPayload
  ) -> String {
    var lines: [String] = []
    lines.append("# AgentPi Mobile Relay Handoff")
    lines.append("")
    lines.append("- Session: `\(payload.session.id)`")
    lines.append("- Branch: `\(payload.session.branchName ?? "unknown")`")
    lines.append("- Source Provider: `\(payload.sourceProvider.rawValue)`")
    lines.append("- Target Provider: `\(payload.targetProvider.rawValue)`")
    lines.append("- Created At: `\(ISO8601DateFormatter().string(from: payload.createdAt))`")
    lines.append("")
    lines.append("## Launch Command")
    lines.append("```bash")
    lines.append(payload.commandLine)
    lines.append("```")
    lines.append("")
    lines.append("## Initial Prompt")
    lines.append(payload.initialPrompt?.isEmpty == false ? payload.initialPrompt! : "_(empty)_")
    lines.append("")
    if let note = payload.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      lines.append("## Note")
      lines.append(note)
      lines.append("")
    }
    lines.append("## Artifacts")
    lines.append("- JSONL: `\(paths.jsonlPath)`")
    lines.append("- Markdown: `\(paths.markdownPath)`")
    lines.append("")
    lines.append("## Manual Handoff")
    lines.append("1. Open the target mobile relay client.")
    lines.append("2. Confirm it is attached to the same project path.")
    lines.append("3. Continue from the latest prompt context in this file.")
    lines.append("")
    return lines.joined(separator: "\n")
  }
}
