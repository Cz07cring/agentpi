import Foundation

public enum AttentionState: Int, CaseIterable, Sendable {
  case awaitingApproval = 0
  case failed = 1
  case waitingUser = 2
  case active = 3
  case idle = 4

  public var isNeedsAction: Bool {
    switch self {
    case .awaitingApproval, .failed, .waitingUser:
      return true
    case .active, .idle:
      return false
    }
  }
}

public enum AttentionResolver {
  public static func resolve(
    status: SessionStatus?,
    isPending: Bool,
    recentActivityDescriptions: [String]
  ) -> AttentionState {
    if isPending {
      return .active
    }

    if hasFailureSignal(recentActivityDescriptions) {
      return .failed
    }

    guard let status else { return .idle }
    switch status {
    case .awaitingApproval:
      return .awaitingApproval
    case .waitingForUser:
      return .waitingUser
    case .thinking, .executingTool:
      return .active
    case .idle:
      return .idle
    }
  }

  private static func hasFailureSignal(_ descriptions: [String]) -> Bool {
    descriptions
      .prefix(8)
      .contains { description in
        let text = description.lowercased()
        return text.contains("failed") || text.contains("error")
      }
  }
}
