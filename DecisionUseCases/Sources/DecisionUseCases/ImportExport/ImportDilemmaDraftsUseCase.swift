import DecisionModels
import DiaryVault
import Foundation

/// Result of importing dilemma draft JSON.
/// It returns the refreshed diary snapshot and the number of imported items for UI confirmation.
public struct DilemmaDraftImportResult: Equatable, Sendable {
  public var snapshot: DiarySnapshot
  public var importedCount: Int

  public init(snapshot: DiarySnapshot, importedCount: Int) {
    self.snapshot = snapshot
    self.importedCount = importedCount
  }
}

/// Progress emitted while importing and analyzing draft JSON.
/// The import sheet uses it to show how many dilemmas have been processed.
public struct DilemmaDraftImportProgress: Equatable, Sendable {
  public var completedCount: Int
  public var totalCount: Int

  public init(completedCount: Int, totalCount: Int) {
    self.completedCount = completedCount
    self.totalCount = totalCount
  }

  public var fractionCompleted: Double {
    guard totalCount > 0 else { return 0 }
    return Double(completedCount) / Double(totalCount)
  }
}

/// Import validation error for dilemma draft JSON.
/// It distinguishes malformed top-level JSON from invalid individual draft items.
public enum DilemmaDraftImportError: LocalizedError, Equatable, Sendable {
  case invalidJSON(String)
  case invalidItem(index: Int, reason: String)

  public var errorDescription: String? {
    switch self {
    case .invalidJSON(let reason):
      "Dilemma draft JSON must be an array of draft objects. \(reason)"
    case .invalidItem(let index, let reason):
      "Dilemma draft item \(index) is invalid. \(reason)"
    }
  }
}

/// Imports one or more dilemma drafts and stores a full analysis for each item.
/// It validates the batch before saving and reports progress while local analysis runs.
public struct ImportDilemmaDraftsUseCase: Sendable {
  private let vault: DiaryVault
  private let analysisGenerator: EntryAnalysisGenerating

  init(vault: DiaryVault, analysisGenerator: EntryAnalysisGenerating) {
    self.vault = vault
    self.analysisGenerator = analysisGenerator
  }

  public func callAsFunction(
    jsonData: Data,
    onProgress: (@Sendable (DilemmaDraftImportProgress) async -> Void)? = nil
  ) async throws -> DilemmaDraftImportResult {
    let drafts = try Self.decodeDrafts(from: jsonData)

    let commands = try drafts.enumerated().map { offset, draft in
      do {
        return try draft.makeEntryDraftCommand()
      } catch {
        throw DilemmaDraftImportError.invalidItem(
          index: offset + 1,
          reason: error.localizedDescription
        )
      }
    }

    await onProgress?(DilemmaDraftImportProgress(completedCount: 0, totalCount: commands.count))
    for (offset, command) in commands.enumerated() {
      let now = Date()
      var entry = command.makeEntry(createdAt: now)
      let analysis = try await analysisGenerator.analysis(for: command, entryID: entry.id)
      entry.updatedAt = Date()
      try vault.saveEntry(entry.storedModel())
      try vault.saveAnalysis(try analysis.storedModel())
      await onProgress?(DilemmaDraftImportProgress(
        completedCount: offset + 1,
        totalCount: commands.count
      ))
    }

    let snapshot = try LoadDiarySnapshotUseCase(vault: vault)()
    return DilemmaDraftImportResult(snapshot: snapshot, importedCount: commands.count)
  }

  private static func decodeDrafts(from jsonData: Data) throws -> [DilemmaDraftJSON] {
    let decoder = JSONDecoder()
    do {
      return try decoder.decode([DilemmaDraftJSON].self, from: jsonData)
    } catch let flatError {
      do {
        let blocks = try decoder.decode([DilemmaDraftBlockJSON].self, from: jsonData)
        return blocks.flatMap(\.dilemmas)
      } catch {
        throw DilemmaDraftImportError.invalidJSON(flatError.localizedDescription)
      }
    }
  }
}

private struct DilemmaDraftBlockJSON: Decodable {
  let dilemmas: [DilemmaDraftJSON]
}
