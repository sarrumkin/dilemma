import Foundation

@MainActor
enum AppLocalization {
  static var language: AppLanguage = .preferred

  static func string(_ value: String.LocalizationValue) -> String {
    String(localized: value, bundle: .main, locale: language.locale)
  }
}
