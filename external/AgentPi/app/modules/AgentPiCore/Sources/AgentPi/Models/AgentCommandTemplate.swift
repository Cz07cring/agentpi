//
//  AgentCommandTemplate.swift
//  AgentPi
//
//  Unified command template models for Claude/Codex/AgentPi.
//

import Foundation

public enum TemplateIntent: String, CaseIterable, Codable, Sendable {
  case startSession = "start_session"
  case resumeSession = "resume_session"
  case batchRun = "batch_run"
  case mobileRelay = "mobile_relay"
}

public enum TemplateExecutionKind: String, CaseIterable, Codable, Sendable {
  case interactiveSession = "interactive_session"
  case batchRun = "batch_run"
  case externalTerminal = "external_terminal"
}

public struct AgentCommandTemplateV1: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var provider: SessionProviderKind
  public var name: String
  public var intent: TemplateIntent
  public var executionKind: TemplateExecutionKind
  /// Executable command string. Can include wrapper subcommands, e.g. "happy codex".
  public var executable: String
  /// Tokenized argument template. Supports placeholders like "{{prompt}}".
  public var argsTemplate: [String]
  public var enabled: Bool
  public var isBuiltin: Bool
  public var sortOrder: Int
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String = UUID().uuidString,
    provider: SessionProviderKind,
    name: String,
    intent: TemplateIntent,
    executionKind: TemplateExecutionKind,
    executable: String,
    argsTemplate: [String] = [],
    enabled: Bool = true,
    isBuiltin: Bool = false,
    sortOrder: Int = 0,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.provider = provider
    self.name = name
    self.intent = intent
    self.executionKind = executionKind
    self.executable = executable
    self.argsTemplate = argsTemplate
    self.enabled = enabled
    self.isBuiltin = isBuiltin
    self.sortOrder = sortOrder
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public var isStructurallyValid: Bool {
    !executable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

public struct AgentCommandTemplateLibraryV1: Codable, Equatable, Sendable {
  public var version: Int
  public var templates: [AgentCommandTemplateV1]

  public init(version: Int = 1, templates: [AgentCommandTemplateV1]) {
    self.version = version
    self.templates = templates
  }
}

public enum BatchTaskRunStatus: String, Codable, Sendable {
  case running
  case succeeded
  case failed
}

public struct BatchTaskOutputChunk: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var timestamp: Date
  public var text: String
  public var isError: Bool

  public init(id: UUID = UUID(), timestamp: Date = Date(), text: String, isError: Bool) {
    self.id = id
    self.timestamp = timestamp
    self.text = text
    self.isError = isError
  }
}

public struct BatchTaskRun: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var provider: SessionProviderKind
  public var templateId: String
  public var templateName: String
  public var commandLine: String
  public var projectPath: String
  public var startedAt: Date
  public var endedAt: Date?
  public var exitCode: Int32?
  public var status: BatchTaskRunStatus
  public var output: [BatchTaskOutputChunk]

  public init(
    id: String = UUID().uuidString,
    provider: SessionProviderKind,
    templateId: String,
    templateName: String,
    commandLine: String,
    projectPath: String,
    startedAt: Date = Date(),
    endedAt: Date? = nil,
    exitCode: Int32? = nil,
    status: BatchTaskRunStatus = .running,
    output: [BatchTaskOutputChunk] = []
  ) {
    self.id = id
    self.provider = provider
    self.templateId = templateId
    self.templateName = templateName
    self.commandLine = commandLine
    self.projectPath = projectPath
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.exitCode = exitCode
    self.status = status
    self.output = output
  }
}
