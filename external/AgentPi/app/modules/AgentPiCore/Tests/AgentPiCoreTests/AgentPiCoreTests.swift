import Testing
@testable import AgentPiCore
import Foundation

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

@Test func loadingStateValidationFailureIsNotLoading() async throws {
  let state = CLILoadingState.repositoryValidationFailed(message: "Not a git repository")
  #expect(state.isLoading == false)
  #expect(state.message == "Not a git repository")
}

@Test func repoValidationResultFactories() async throws {
  let valid = RepoValidationResult.valid(gitRootPath: "/tmp/repo")
  #expect(valid.isGitRepo == true)
  #expect(valid.gitRootPath == "/tmp/repo")
  #expect(valid.reasonCode == nil)

  let invalid = RepoValidationResult.invalid(code: "GIT_NOT_REPO", message: "invalid")
  #expect(invalid.isGitRepo == false)
  #expect(invalid.reasonCode == "GIT_NOT_REPO")
  #expect(invalid.reasonMessage == "invalid")
}

@Test func worktreeCreationResolvesAmbiguousStartPoint() async throws {
  let fileManager = FileManager.default
  let tempBase = fileManager.temporaryDirectory.appendingPathComponent("agentpi-test-\(UUID().uuidString)")
  let repoURL = tempBase.appendingPathComponent("repo")

  try fileManager.createDirectory(at: repoURL, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: tempBase) }

  try runGit(["init"], at: repoURL.path)
  try runGit(["config", "user.name", "AgentPi Test"], at: repoURL.path)
  try runGit(["config", "user.email", "agentpi@test.local"], at: repoURL.path)
  try "hello\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
  try runGit(["add", "README.md"], at: repoURL.path)
  try runGit(["commit", "-m", "init"], at: repoURL.path)

  // Build the exact ambiguity: same short name exists as both head and tag.
  try runGit(["checkout", "-b", "arbitrage_scaffold/main"], at: repoURL.path)
  try runGit(["tag", "arbitrage_scaffold/main"], at: repoURL.path)
  try runGit(["checkout", "main"], at: repoURL.path)

  let service = GitWorktreeService()
  let branchName = "agentpi-test-\(String(UUID().uuidString.prefix(8)).lowercased())"
  let directoryName = "wt-\(branchName)"

  let worktreePath = try await service.createWorktreeWithNewBranch(
    at: repoURL.path,
    newBranchName: branchName,
    directoryName: directoryName,
    startPoint: "arbitrage_scaffold/main"
  )

  #expect(fileManager.fileExists(atPath: worktreePath))
}

@Test func validateRepositoryRejectsNonGitPath() async throws {
  let fileManager = FileManager.default
  let nonGitDir = fileManager.temporaryDirectory.appendingPathComponent("agentpi-non-git-\(UUID().uuidString)")
  try fileManager.createDirectory(at: nonGitDir, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: nonGitDir) }

  let service = GitWorktreeService()
  let result = await service.validateRepository(at: nonGitDir.path)

  #expect(result.isGitRepo == false)
  #expect(result.reasonCode == "GIT_NOT_REPO")
}

@Test func worktreeCreationResolvesMainBranchTagAmbiguity() async throws {
  let fileManager = FileManager.default
  let tempBase = fileManager.temporaryDirectory.appendingPathComponent("agentpi-main-ambiguous-\(UUID().uuidString)")
  let repoURL = tempBase.appendingPathComponent("repo")

  try fileManager.createDirectory(at: repoURL, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: tempBase) }

  try runGit(["init"], at: repoURL.path)
  try runGit(["config", "user.name", "AgentPi Test"], at: repoURL.path)
  try runGit(["config", "user.email", "agentpi@test.local"], at: repoURL.path)
  try "hello\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
  try runGit(["add", "README.md"], at: repoURL.path)
  try runGit(["commit", "-m", "init"], at: repoURL.path)

  let currentBranch = try runGitOutput(["rev-parse", "--abbrev-ref", "HEAD"], at: repoURL.path)
    .trimmingCharacters(in: .whitespacesAndNewlines)
  try runGit(["tag", currentBranch], at: repoURL.path)

  let service = GitWorktreeService()
  let branchName = "agentpi-test-\(String(UUID().uuidString.prefix(8)).lowercased())"
  let directoryName = "wt-\(branchName)"

  let worktreePath = try await service.createWorktreeWithNewBranch(
    at: repoURL.path,
    newBranchName: branchName,
    directoryName: directoryName,
    startPoint: currentBranch
  )

  #expect(fileManager.fileExists(atPath: worktreePath))
}

@Test func worktreeCreationFailsFastOnInvalidStartPoint() async throws {
  let fileManager = FileManager.default
  let tempBase = fileManager.temporaryDirectory.appendingPathComponent("agentpi-invalid-start-\(UUID().uuidString)")
  let repoURL = tempBase.appendingPathComponent("repo")

  try fileManager.createDirectory(at: repoURL, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: tempBase) }

  try runGit(["init"], at: repoURL.path)
  try runGit(["config", "user.name", "AgentPi Test"], at: repoURL.path)
  try runGit(["config", "user.email", "agentpi@test.local"], at: repoURL.path)
  try "hello\n".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
  try runGit(["add", "README.md"], at: repoURL.path)
  try runGit(["commit", "-m", "init"], at: repoURL.path)

  let service = GitWorktreeService()
  let branchName = "agentpi-test-\(String(UUID().uuidString.prefix(8)).lowercased())"
  let directoryName = "wt-\(branchName)"

  do {
    _ = try await service.createWorktreeWithNewBranch(
      at: repoURL.path,
      newBranchName: branchName,
      directoryName: directoryName,
      startPoint: "does/not/exist"
    )
    Issue.record("Expected createWorktreeWithNewBranch to fail for invalid start-point.")
  } catch {
    _ = Bool(true)
  }
}

@Test func sanitizeBranchNameTransliteratesAndConstrains() async throws {
  let sanitized = GitWorktreeService.sanitizeBranchName("学习下这个仓库/平仓-收益分析")
  #expect(sanitized.contains("/") == false)
  #expect(sanitized.contains(" ") == false)
  #expect(sanitized.isEmpty == false)
  #expect(sanitized.count <= 48)
}

@Test func worktreeDirectoryNameUsesStableShortForm() async throws {
  let directoryA = GitWorktreeService.worktreeDirectoryName(
    for: "学习下这个仓库-be7b8a",
    repoName: "arbitrage_scaffold"
  )
  let directoryB = GitWorktreeService.worktreeDirectoryName(
    for: "学习下这个仓库-be7b8a",
    repoName: "arbitrage_scaffold"
  )

  #expect(directoryA == directoryB)
  #expect(directoryA.count <= 64)
}

private func runGit(_ args: [String], at directory: String) throws {
  _ = try runGitOutput(args, at: directory)
}

@discardableResult
private func runGitOutput(_ args: [String], at directory: String) throws -> String {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
  process.arguments = args
  process.currentDirectoryURL = URL(fileURLWithPath: directory)

  let stdout = Pipe()
  let stderr = Pipe()
  process.standardOutput = stdout
  process.standardError = stderr

  try process.run()
  process.waitUntilExit()

  let stdoutOutput = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

  guard process.terminationStatus == 0 else {
    let output = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    throw NSError(domain: "AgentPiCoreTests", code: Int(process.terminationStatus), userInfo: [
      NSLocalizedDescriptionKey: "git \(args.joined(separator: " ")) failed: \(output)"
    ])
  }

  return stdoutOutput
}
