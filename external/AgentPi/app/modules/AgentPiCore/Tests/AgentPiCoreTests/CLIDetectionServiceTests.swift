import Foundation
import Testing
@testable import AgentPiCore

@Suite(.serialized)
struct CLIDetectionServiceTests {
  @Test("availability status: executable found is launchable")
  func availabilityStatusExecutableFound() {
    let status = CLIDetectionService.availabilityStatus(
      isExecutableFound: true,
      hasDataDirectory: true
    )
    #expect(status == .available)
    #expect(status.isLaunchable == true)
  }

  @Test("availability status: data dir only is misconfigured")
  func availabilityStatusDataDirectoryOnly() {
    let status = CLIDetectionService.availabilityStatus(
      isExecutableFound: false,
      hasDataDirectory: true
    )
    #expect(status == .misconfigured)
    #expect(status.isLaunchable == false)
  }

  @Test("availability status: no executable and no data dir is missing")
  func availabilityStatusMissing() {
    let status = CLIDetectionService.availabilityStatus(
      isExecutableFound: false,
      hasDataDirectory: false
    )
    #expect(status == .missing)
    #expect(status.isLaunchable == false)
  }
}
