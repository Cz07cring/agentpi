//
//  RepoValidationResult.swift
//  AgentPi
//

import Foundation

public struct RepoValidationResult: Equatable, Sendable {
  public let isGitRepo: Bool
  public let gitRootPath: String?
  public let reasonCode: String?
  public let reasonMessage: String?

  public init(
    isGitRepo: Bool,
    gitRootPath: String? = nil,
    reasonCode: String? = nil,
    reasonMessage: String? = nil
  ) {
    self.isGitRepo = isGitRepo
    self.gitRootPath = gitRootPath
    self.reasonCode = reasonCode
    self.reasonMessage = reasonMessage
  }

  public static func valid(gitRootPath: String) -> RepoValidationResult {
    RepoValidationResult(
      isGitRepo: true,
      gitRootPath: gitRootPath,
      reasonCode: nil,
      reasonMessage: nil
    )
  }

  public static func invalid(code: String, message: String) -> RepoValidationResult {
    RepoValidationResult(
      isGitRepo: false,
      gitRootPath: nil,
      reasonCode: code,
      reasonMessage: message
    )
  }
}
