//
//  MobileRelayTaskStore.swift
//  AgentPi
//
//  Shared store for mobile relay task history with persistence.
//

import Foundation

@MainActor
@Observable
public final class MobileRelayTaskStore {
  public static let shared = MobileRelayTaskStore()

  public private(set) var tasks: [MobileRelayTask] = []

  private let defaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let maxTasks = 200

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    loadPersistedTasks()
  }

  public func appendTask(_ task: MobileRelayTask) {
    tasks.insert(task, at: 0)
    trimIfNeeded()
    persistTasks()
  }

  public func appendOutput(taskId: String, text: String, isError: Bool) {
    guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
    tasks[index].output.append(MobileRelayOutputChunk(text: text, isError: isError))
    persistTasks()
  }

  public func markFinished(taskId: String, status: MobileRelayTaskStatus, exitCode: Int32?) {
    guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
    tasks[index].endedAt = Date()
    tasks[index].status = status
    tasks[index].exitCode = exitCode
    persistTasks()
  }

  public func task(by id: String) -> MobileRelayTask? {
    tasks.first(where: { $0.id == id })
  }

  private func trimIfNeeded() {
    if tasks.count > maxTasks {
      tasks = Array(tasks.prefix(maxTasks))
    }
  }

  private func persistTasks() {
    guard let data = try? encoder.encode(tasks) else { return }
    defaults.set(data, forKey: AgentPiDefaults.mobileRelayTasks)
  }

  private func loadPersistedTasks() {
    guard let data = defaults.data(forKey: AgentPiDefaults.mobileRelayTasks),
      let decoded = try? decoder.decode([MobileRelayTask].self, from: data)
    else {
      tasks = []
      return
    }
    tasks = Array(decoded.prefix(maxTasks))
  }
}
