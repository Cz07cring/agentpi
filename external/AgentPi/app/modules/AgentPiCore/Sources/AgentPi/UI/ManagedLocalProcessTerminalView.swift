//
//  ManagedLocalProcessTerminalView.swift
//  AgentPi
//
//  LocalProcessTerminalView-equivalent with explicit process lifecycle control.
//

import AppKit
import Darwin
import SwiftTerm

/// Delegate for ManagedLocalProcessTerminalView process events.
public protocol ManagedLocalProcessTerminalViewDelegate: AnyObject {
  func sizeChanged(source: ManagedLocalProcessTerminalView, newCols: Int, newRows: Int)
  func setTerminalTitle(source: ManagedLocalProcessTerminalView, title: String)
  func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?)
  func processTerminated(source: TerminalView, exitCode: Int32?)
}

/// Local-process terminal view with explicit process control.
open class ManagedLocalProcessTerminalView: TerminalView, TerminalViewDelegate, LocalProcessDelegate {
  private var process: LocalProcess!
  private var outputLineBuffer: String = ""

  /// Delegate for process-related events.
  public weak var processDelegate: ManagedLocalProcessTerminalViewDelegate?

  /// Plain-text markers used to suppress noisy wrapper banners from specific CLIs.
  public var suppressedOutputSubstrings: [String] = []

  /// Minimum PTY columns to report to child process.
  /// Useful for CLIs that are unstable in very narrow terminal widths.
  public var minimumPTYColumns: Int = 1

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    terminalDelegate = self
    process = LocalProcess(delegate: self)
  }

  /// PID of the running child process, if any.
  public var currentProcessId: pid_t? {
    process.running ? process.shellPid : nil
  }

  // MARK: - TerminalViewDelegate

  public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
    guard process.running else { return }
    var size = getWindowSize()
    let _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &size)
    // Notify the child process group about the resize so TUI apps reflow immediately.
    let pid = process.shellPid
    if pid > 0 {
      if killpg(pid, SIGWINCH) != 0 {
        _ = kill(pid, SIGWINCH)
      }
    }
    processDelegate?.sizeChanged(source: self, newCols: Int(size.ws_col), newRows: newRows)
  }

  public func clipboardCopy(source: TerminalView, content: Data) {
    if let str = String(bytes: content, encoding: .utf8) {
      let pasteBoard = NSPasteboard.general
      pasteBoard.clearContents()
      pasteBoard.writeObjects([str as NSString])
    }
  }

  public override func paste(_ sender: Any?) {
    let pasteboard = NSPasteboard.general

    if let urls = pasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    ) as? [URL],
       let url = urls.first {
      sendPathToTerminal(url.path)
      return
    }

    if let imageData =
        pasteboard.data(forType: .png)
        ?? pasteboard.data(forType: .tiff)
        ?? pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")),
       let url = writeImageDataToTemp(imageData) {
      sendPathToTerminal(url.path)
      return
    }

    if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
       let image = images.first,
       let url = writeImageToTemp(image) {
      sendPathToTerminal(url.path)
      return
    }

    super.paste(sender as Any)
  }

  public func setTerminalTitle(source: TerminalView, title: String) {
    processDelegate?.setTerminalTitle(source: self, title: title)
  }

  public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
    processDelegate?.hostCurrentDirectoryUpdate(source: source, directory: directory)
  }

  open func send(source: TerminalView, data: ArraySlice<UInt8>) {
    process.send(data: data)
  }

  public func setHostLogging(directory: String?) {
    process.setHostLogging(directory: directory)
  }

  open func scrolled(source: TerminalView, position: Double) {}

  open func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

  // MARK: - Process Control

  public func startProcess(
    executable: String = "/bin/bash",
    args: [String] = [],
    environment: [String]? = nil,
    execName: String? = nil
  ) {
    process.startProcess(
      executable: executable,
      args: args,
      environment: environment,
      execName: execName
    )
  }

  /// Terminates the process group for the running child.
  public func terminateProcessTree(graceSeconds: TimeInterval = 1.0) {
    guard process.running else { return }
    let pid = process.shellPid
    guard pid > 0 else { return }

    if killpg(pid, SIGTERM) != 0 {
      _ = kill(pid, SIGTERM)
    }

    guard graceSeconds > 0 else { return }
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + graceSeconds) { [weak self] in
      guard let self, self.process.running else { return }
      AppLogger.session.warning("Process group PID=\(pid) still alive; sending SIGKILL")
      _ = killpg(pid, SIGKILL)
    }
  }

  // MARK: - LocalProcessDelegate

  open func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
    flushOutputLineBuffer()
    processDelegate?.processTerminated(source: self, exitCode: exitCode)
  }

  open func dataReceived(slice: ArraySlice<UInt8>) {
    guard !suppressedOutputSubstrings.isEmpty else {
      feed(byteArray: slice)
      return
    }

    guard let chunk = String(bytes: slice, encoding: .utf8) else {
      feed(byteArray: slice)
      return
    }

    outputLineBuffer.append(chunk)
    drainOutputLineBuffer()
  }

  private func drainOutputLineBuffer() {
    while let newlineRange = outputLineBuffer.range(of: "\n") {
      let line = String(outputLineBuffer[..<newlineRange.upperBound])
      outputLineBuffer.removeSubrange(outputLineBuffer.startIndex..<newlineRange.upperBound)
      if shouldSuppressOutputLine(line) {
        continue
      }
      feed(text: line)
    }
  }

  private func flushOutputLineBuffer() {
    guard !outputLineBuffer.isEmpty else { return }
    if !shouldSuppressOutputLine(outputLineBuffer) {
      feed(text: outputLineBuffer)
    }
    outputLineBuffer.removeAll(keepingCapacity: true)
  }

  private func shouldSuppressOutputLine(_ line: String) -> Bool {
    suppressedOutputSubstrings.contains { marker in
      line.localizedCaseInsensitiveContains(marker)
    }
  }

  open override func removeFromSuperview() {
    flushOutputLineBuffer()
    super.removeFromSuperview()
  }

  open func getWindowSize() -> winsize {
    let f: CGRect = frame
    let effectiveCols = max(1, max(terminal.cols, minimumPTYColumns))
    return winsize(
      ws_row: UInt16(terminal.rows),
      ws_col: UInt16(effectiveCols),
      ws_xpixel: UInt16(f.width),
      ws_ypixel: UInt16(f.height)
    )
  }

  // MARK: - Clipboard Helpers

  private func sendPathToTerminal(_ path: String) {
    let quotedPath = path.contains(" ") ? "\"\(path)\"" : path
    send(txt: quotedPath + " ")
  }

  private func writeImageDataToTemp(_ data: Data) -> URL? {
    if let image = NSImage(data: data) {
      return writeImageToTemp(image)
    }
    return nil
  }

  private func writeImageToTemp(_ image: NSImage) -> URL? {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
      return nil
    }

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("pasted_image_\(UUID().uuidString).png")
    do {
      try pngData.write(to: tempURL)
      return tempURL
    } catch {
      return nil
    }
  }
}
