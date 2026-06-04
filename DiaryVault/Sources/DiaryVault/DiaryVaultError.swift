import Foundation

public enum DiaryVaultError: LocalizedError, Equatable, Sendable {
  case database(String)
  case notFound

  public var errorDescription: String? {
    switch self {
    case .database(let message):
      "Database error: \(message)"
    case .notFound:
      "Record not found."
    }
  }
}
