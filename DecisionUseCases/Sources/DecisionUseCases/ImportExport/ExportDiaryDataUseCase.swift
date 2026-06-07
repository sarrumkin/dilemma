import DecisionModels
import DiaryVault
import Foundation

/// Exports the full diary as canonical JSON.
/// It maps vault records back into `DiaryExport` so exports do not leak storage DTOs.
public struct ExportDiaryDataUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction() throws -> Data {
    let export = try vault.exportData().decisionModel()
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(export)
  }

  public func makeTemporaryExportFile(now: Date = Date()) throws -> URL {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let timestamp = formatter.string(from: now)
      .replacingOccurrences(of: ":", with: "-")
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("dilemma-export-\(timestamp)")
      .appendingPathExtension("json")
    try callAsFunction().write(to: url, options: .atomic)
    return url
  }
}
