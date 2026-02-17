import Foundation
import Testing
@testable import AgentPiCore

@Suite(.serialized)
struct ProxyEnvironmentTests {
  @Test("disabled proxy does not inject values")
  func disabledProxyNoValues() {
    let defaults = makeDefaults()
    defaults.set(false, forKey: AgentPiDefaults.proxyEnabled)

    let values = ProxyEnvironment.resolvedValues(
      defaults: defaults,
      processEnvironment: ["HTTP_PROXY": "http://127.0.0.1:7890"]
    )
    #expect(values.isEmpty)
  }

  @Test("enabled proxy reads configured values and mirrors lower-case keys")
  func enabledConfiguredValues() {
    let defaults = makeDefaults()
    defaults.set(true, forKey: AgentPiDefaults.proxyEnabled)
    defaults.set("http://127.0.0.1:7890", forKey: AgentPiDefaults.proxyHTTP)
    defaults.set("localhost,127.0.0.1", forKey: AgentPiDefaults.proxyNO)

    let values = ProxyEnvironment.resolvedValues(defaults: defaults, processEnvironment: [:])

    #expect(values["HTTP_PROXY"] == "http://127.0.0.1:7890")
    #expect(values["http_proxy"] == "http://127.0.0.1:7890")
    #expect(values["HTTPS_PROXY"] == "http://127.0.0.1:7890")
    #expect(values["ALL_PROXY"] == "http://127.0.0.1:7890")
    #expect(values["NO_PROXY"] == "localhost,127.0.0.1")
    #expect(values["no_proxy"] == "localhost,127.0.0.1")
  }

  @Test("enabled proxy falls back to process environment when setting is empty")
  func enabledFallbackToProcessEnvironment() {
    let defaults = makeDefaults()
    defaults.set(true, forKey: AgentPiDefaults.proxyEnabled)

    let values = ProxyEnvironment.resolvedValues(
      defaults: defaults,
      processEnvironment: [
        "http_proxy": "http://env-proxy:7890",
        "NO_PROXY": "localhost"
      ]
    )

    #expect(values["HTTP_PROXY"] == "http://env-proxy:7890")
    #expect(values["HTTPS_PROXY"] == "http://env-proxy:7890")
    #expect(values["ALL_PROXY"] == "http://env-proxy:7890")
    #expect(values["NO_PROXY"] == "localhost")
  }

  @Test("enabled proxy uses built-in defaults when setting and env are empty")
  func enabledUsesBuiltInDefaults() {
    let defaults = makeDefaults()
    defaults.set(true, forKey: AgentPiDefaults.proxyEnabled)

    let values = ProxyEnvironment.resolvedValues(defaults: defaults, processEnvironment: [:])

    #expect(values["HTTP_PROXY"] == AgentPiDefaults.defaultProxyHTTP)
    #expect(values["HTTPS_PROXY"] == AgentPiDefaults.defaultProxyHTTPS)
    #expect(values["ALL_PROXY"] == AgentPiDefaults.defaultProxyALL)
    #expect(values["NO_PROXY"] == AgentPiDefaults.defaultProxyNO)
  }

  @Test("shell export snippet quotes values safely")
  func shellExportSnippetEscapesSingleQuote() {
    let defaults = makeDefaults()
    defaults.set(true, forKey: AgentPiDefaults.proxyEnabled)
    defaults.set("http://user:pa'ss@127.0.0.1:7890", forKey: AgentPiDefaults.proxyHTTP)

    let snippet = ProxyEnvironment.shellExportSnippet(defaults: defaults, processEnvironment: [:])

    #expect(snippet.contains("export HTTP_PROXY='http://user:pa'\\''ss@127.0.0.1:7890'"))
    #expect(snippet.contains("export http_proxy='http://user:pa'\\''ss@127.0.0.1:7890'"))
  }

  private func makeDefaults() -> UserDefaults {
    let suiteName = "ProxyEnvironmentTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}
