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

@MainActor
enum AppErrorMessage {
  static func message(for _: Error, context: AppErrorContext) -> String {
    switch context {
    case .loadDiary:
      AppLocalization.string("Could not load your diary.")
    case .analyzeEntry:
      AppLocalization.string("Could not analyze this entry.")
    case .importJSON:
      AppLocalization.string("Could not import this JSON.")
    case .saveFeedback:
      AppLocalization.string("Could not save feedback.")
    case .exportEntry:
      AppLocalization.string("Could not prepare this export.")
    case .prepareDiary:
      AppLocalization.string("Could not prepare the private diary.")
    case .exportDiary:
      AppLocalization.string("Could not export diary data.")
    case .deleteEntry:
      AppLocalization.string("Could not delete this dilemma.")
    case .deleteData:
      AppLocalization.string("Could not delete local diary data.")
    case .loadStatistics:
      AppLocalization.string("Could not load statistics.")
    }
  }
}
