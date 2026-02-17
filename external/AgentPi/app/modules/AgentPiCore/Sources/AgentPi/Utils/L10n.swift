import Foundation

public enum L10n {
  private static var selectedLanguageCode: String {
    UserDefaults.standard.string(forKey: AgentPiDefaults.selectedLanguage) ?? "system"
  }

  private static var localizedBundle: Bundle {
    let code = selectedLanguageCode
    guard code != "system" else { return .module }

    if let bundle = bundle(forLocalizationCode: code) {
      return bundle
    }

    // Fallback for region/script-qualified codes like zh-Hans-CN.
    if let baseCode = code.split(separator: "-").first {
      let prefix = "\(baseCode)-".lowercased()
      if let matched = Bundle.module.localizations.first(where: { $0.lowercased().hasPrefix(prefix) }),
         let bundle = bundle(forLocalizationCode: matched) {
        return bundle
      }

      if let bundle = bundle(forLocalizationCode: String(baseCode)) {
        return bundle
      }
    }

    return .module
  }

  private static var formattingLocale: Locale {
    let code = selectedLanguageCode
    return code == "system" ? Locale.current : Locale(identifier: code)
  }

  public static func t(_ key: String, _ fallback: String) -> String {
    let localized = localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")
    return localized == key ? fallback : localized
  }

  public static func f(_ key: String, _ fallback: String, _ args: CVarArg...) -> String {
    let format = t(key, fallback)
    return String(format: format, locale: formattingLocale, arguments: args)
  }

  private static func bundle(forLocalizationCode code: String) -> Bundle? {
    let candidates = [code, code.replacingOccurrences(of: "-", with: "_")]

    for candidate in candidates {
      if let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
         let bundle = Bundle(path: path) {
        return bundle
      }
    }

    return nil
  }
}
