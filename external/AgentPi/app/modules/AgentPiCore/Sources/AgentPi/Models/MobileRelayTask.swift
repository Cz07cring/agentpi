//
//  MobileRelayTask.swift
//  AgentPi
//
//  Models for one-click mobile relay handoff tasks.
//

import Foundation

public enum MobileRelayTaskStatus: String, Codable, Sendable {
  case running
  case succeeded
  case failed
  case cancelled
}

public struct MobileRelayOutputChunk: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var timestamp: Date
  public var text: String
  public var isError: Bool

  public init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    text: String,
    isError: Bool
  ) {
    self.id = id
    self.timestamp = timestamp
    self.text = text
    self.isError = isError
  }
}

public struct MobileRelayTask: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var sessionId: String
  public var sessionShortId: String
  public var sourceProvider: SessionProviderKind
  public var targetProvider: SessionProviderKind
  public var templateId: String
  public var templateName: String
  public var commandLine: String
  public var projectPath: String
  public var branch: String?
  public var note: String?
  public var initialPrompt: String?
  public var handoffJSONLPath: String
  public var handoffMarkdownPath: String
  public var startedAt: Date
  public var endedAt: Date?
  public var exitCode: Int32?
  public var status: MobileRelayTaskStatus
  public var output: [MobileRelayOutputChunk]

  public init(
    id: String = UUID().uuidString,
    sessionId: String,
    sessionShortId: String,
    sourceProvider: SessionProviderKind,
    targetProvider: SessionProviderKind,
    templateId: String,
    templateName: String,
    commandLine: String,
    projectPath: String,
    branch: String?,
    note: String?,
    initialPrompt: String?,
    handoffJSONLPath: String,
    handoffMarkdownPath: String,
    startedAt: Date = Date(),
    endedAt: Date? = nil,
    exitCode: Int32? = nil,
    status: MobileRelayTaskStatus = .running,
    output: [MobileRelayOutputChunk] = []
  ) {
    self.id = id
    self.sessionId = sessionId
    self.sessionShortId = sessionShortId
    self.sourceProvider = sourceProvider
    self.targetProvider = targetProvider
    self.templateId = templateId
    self.templateName = templateName
    self.commandLine = commandLine
    self.projectPath = projectPath
    self.branch = branch
    self.note = note
    self.initialPrompt = initialPrompt
    self.handoffJSONLPath = handoffJSONLPath
    self.handoffMarkdownPath = handoffMarkdownPath
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.exitCode = exitCode
    self.status = status
    self.output = output
  }
}

public struct MobileRelayLaunchRequest: Sendable, Equatable {
  public var targetProvider: SessionProviderKind
  public var templateId: String?
  public var note: String?

  public init(
    targetProvider: SessionProviderKind,
    templateId: String? = nil,
    note: String? = nil
  ) {
    self.targetProvider = targetProvider
    self.templateId = templateId
    self.note = note
  }
}
