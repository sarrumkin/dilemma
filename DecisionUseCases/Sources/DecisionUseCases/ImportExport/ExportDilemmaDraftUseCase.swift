import DecisionModels
import Foundation

/// Exports a single entry as the dilemma draft JSON format.
/// It supports sharing one dilemma with its optional full analysis payload.
public struct ExportDilemmaDraftUseCase: Sendable {
  public init() {}

  public func callAsFunction(entry: DiaryEntry, analysis: DecisionAnalysis? = nil) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(try DilemmaDraftJSON(entry: entry, analysis: analysis).validated())
  }

  public func makeTemporaryExportFile(
    entry: DiaryEntry,
    analysis: DecisionAnalysis? = nil,
    now: Date = Date()
  ) throws -> URL {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let timestamp = formatter.string(from: now)
      .replacingOccurrences(of: ":", with: "-")
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("dilemma-draft-\(timestamp)")
      .appendingPathExtension("json")
    try callAsFunction(entry: entry, analysis: analysis).write(to: url, options: .atomic)
    return url
  }
}
