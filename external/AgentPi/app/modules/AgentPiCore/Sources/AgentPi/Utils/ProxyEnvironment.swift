//
//  ProxyEnvironment.swift
//  AgentPi
//

import Foundation

/// Applies user-configured proxy settings to CLI environments.
public enum ProxyEnvironment {
  public static func apply(to environment: inout [String: String]) {
    let values = resolvedValues(
      defaults: .standard,
      processEnvironment: ProcessInfo.processInfo.environment
    )
    for (key, value) in values {
      environment[key] = value
    }
  }

  public static func shellExportSnippet() -> String {
    shellExportSnippet(
      defaults: .standard,
      processEnvironment: ProcessInfo.processInfo.environment
    )
  }

  static func shellExportSnippet(
    defaults: UserDefaults,
    processEnvironment: [String: String]
  ) -> String {
    let values = resolvedValues(defaults: defaults, processEnvironment: processEnvironment)
    guard !values.isEmpty else { return "" }

    let orderedKeys = [
      "HTTP_PROXY", "http_proxy",
      "HTTPS_PROXY", "https_proxy",
      "ALL_PROXY", "all_proxy",
      "NO_PROXY", "no_proxy"
    ]

    var lines: [String] = []
    for key in orderedKeys {
      guard let value = values[key], !value.isEmpty else { continue }
      lines.append("export \(key)=\(singleQuoted(value))")
    }
    return lines.joined(separator: "; ") + (lines.isEmpty ? "" : "; ")
  }

  static func resolvedValues(
    defaults: UserDefaults,
    processEnvironment: [String: String]
  ) -> [String: String] {
    guard defaults.bool(forKey: AgentPiDefaults.proxyEnabled) else { return [:] }

    let configuredHTTP = cleaned(defaults.string(forKey: AgentPiDefaults.proxyHTTP))
    let configuredHTTPS = cleaned(defaults.string(forKey: AgentPiDefaults.proxyHTTPS))
    let configuredALL = cleaned(defaults.string(forKey: AgentPiDefaults.proxyALL))
    let envHTTP = cleaned(processEnvironment["HTTP_PROXY"] ?? processEnvironment["http_proxy"])
    let envHTTPS = cleaned(processEnvironment["HTTPS_PROXY"] ?? processEnvironment["https_proxy"])
    let envALL = cleaned(processEnvironment["ALL_PROXY"] ?? processEnvironment["all_proxy"])

    let http = configuredOrEnvironmentValue(
      defaults.string(forKey: AgentPiDefaults.proxyHTTP),
      upper: "HTTP_PROXY",
      lower: "http_proxy",
      defaultValue: AgentPiDefaults.defaultProxyHTTP,
      processEnvironment: processEnvironment
    )
    var https = configuredOrEnvironmentValue(
      defaults.string(forKey: AgentPiDefaults.proxyHTTPS),
      upper: "HTTPS_PROXY",
      lower: "https_proxy",
      defaultValue: "",
      processEnvironment: processEnvironment
    )
    var all = configuredOrEnvironmentValue(
      defaults.string(forKey: AgentPiDefaults.proxyALL),
      upper: "ALL_PROXY",
      lower: "all_proxy",
      defaultValue: "",
      processEnvironment: processEnvironment
    )
    let no = configuredOrEnvironmentValue(
      defaults.string(forKey: AgentPiDefaults.proxyNO),
      upper: "NO_PROXY",
      lower: "no_proxy",
      defaultValue: AgentPiDefaults.defaultProxyNO,
      processEnvironment: processEnvironment
    )

    if https.isEmpty { https = http }
    if all.isEmpty {
      let hasExplicitOrEnvironmentProxy = !configuredHTTP.isEmpty || !configuredHTTPS.isEmpty || !configuredALL.isEmpty
        || !envHTTP.isEmpty || !envHTTPS.isEmpty || !envALL.isEmpty
      if hasExplicitOrEnvironmentProxy {
        all = https.isEmpty ? http : https
      } else {
        all = AgentPiDefaults.defaultProxyALL
      }
    }

    if http.isEmpty && https.isEmpty && all.isEmpty && no.isEmpty {
      return [:]
    }

    var values: [String: String] = [:]
    if !http.isEmpty {
      values["HTTP_PROXY"] = http
      values["http_proxy"] = http
    }
    if !https.isEmpty {
      values["HTTPS_PROXY"] = https
      values["https_proxy"] = https
    }
    if !all.isEmpty {
      values["ALL_PROXY"] = all
      values["all_proxy"] = all
    }
    if !no.isEmpty {
      values["NO_PROXY"] = no
      values["no_proxy"] = no
    }

    return values
  }

  private static func cleaned(_ value: String?) -> String {
    value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private static func singleQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }

  private static func configuredOrEnvironmentValue(
    _ configured: String?,
    upper: String,
    lower: String,
    defaultValue: String,
    processEnvironment: [String: String]
  ) -> String {
    let configuredValue = cleaned(configured)
    if !configuredValue.isEmpty {
      return configuredValue
    }
    let environmentValue = cleaned(processEnvironment[upper] ?? processEnvironment[lower])
    if !environmentValue.isEmpty {
      return environmentValue
    }
    return cleaned(defaultValue)
  }
}
