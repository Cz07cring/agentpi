import Foundation
import Testing
@testable import AgentPiCore

@Suite(.serialized)
struct HubAttentionPriorityTests {
  @Test("attention states sort by action priority")
  func attentionPrioritySort() {
    let states: [AttentionState] = [.idle, .active, .waitingUser, .failed, .awaitingApproval]
    let sorted = states.sorted { $0.rawValue < $1.rawValue }
    #expect(sorted == [.awaitingApproval, .failed, .waitingUser, .active, .idle])
  }

  @Test("needs action flags are limited to actionable states")
  func needsActionFlags() {
    #expect(AttentionState.awaitingApproval.isNeedsAction)
    #expect(AttentionState.failed.isNeedsAction)
    #expect(AttentionState.waitingUser.isNeedsAction)
    #expect(!AttentionState.active.isNeedsAction)
    #expect(!AttentionState.idle.isNeedsAction)
  }

  @Test("resolver maps status into attention state")
  func resolverStatusMapping() {
    #expect(
      AttentionResolver.resolve(
        status: .awaitingApproval(tool: "Bash"),
        isPending: false,
        recentActivityDescriptions: []
      ) == .awaitingApproval
    )

    #expect(
      AttentionResolver.resolve(
        status: .waitingForUser,
        isPending: false,
        recentActivityDescriptions: []
      ) == .waitingUser
    )

    #expect(
      AttentionResolver.resolve(
        status: .idle,
        isPending: false,
        recentActivityDescriptions: ["worktree failed: timeout"]
      ) == .failed
    )
  }
}
