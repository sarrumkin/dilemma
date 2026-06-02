import Foundation

enum AppErrorContext {
  case loadDiary
  case analyzeEntry
  case importJSON
  case saveFeedback
  case exportEntry
  case prepareDiary
  case exportDiary
  case deleteEntry
  case deleteData
  case loadStatistics
}

enum AppErrorMessage {
  static func message(for _: Error, context: AppErrorContext) -> String {
    switch context {
    case .loadDiary:
      String(localized: "Could not load your diary.")
    case .analyzeEntry:
      String(localized: "Could not analyze this entry.")
    case .importJSON:
      String(localized: "Could not import this JSON.")
    case .saveFeedback:
      String(localized: "Could not save feedback.")
    case .exportEntry:
      String(localized: "Could not prepare this export.")
    case .prepareDiary:
      String(localized: "Could not prepare the private diary.")
    case .exportDiary:
      String(localized: "Could not export diary data.")
    case .deleteEntry:
      String(localized: "Could not delete this dilemma.")
    case .deleteData:
      String(localized: "Could not delete local diary data.")
    case .loadStatistics:
      String(localized: "Could not load statistics.")
    }
  }
}
