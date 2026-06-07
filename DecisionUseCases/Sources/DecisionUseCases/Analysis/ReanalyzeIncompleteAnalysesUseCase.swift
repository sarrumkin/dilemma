import DecisionModels
import DiaryVault
import Foundation

/// Result of reanalyzing incomplete or outdated stored analyses.
///
/// It returns a refreshed snapshot plus counters so Settings can report how much work was completed
/// and whether any entries failed during the run.
public struct ReanalyzeIncompleteAnalysesResult: Equatable, Sendable {
  public var snapshot: DiarySnapshot
  public var updatedCount: Int
  public var failedCount: Int

  public init(snapshot: DiarySnapshot, updatedCount: Int, failedCount: Int) {
    self.snapshot = snapshot
    self.updatedCount = updatedCount
    self.failedCount = failedCount
  }
}

/// Progress for reanalyzing incomplete analyses.
///
/// The UI uses it to show that reanalysis is running, which entry is currently being processed, how
/// many analyses remain, and how many failed without stopping the whole batch.
public struct ReanalyzeIncompleteAnalysesProgress: Equatable, Sendable {
  public var totalCount: Int
  public var completedCount: Int
  public var remainingCount: Int
  public var currentEntryID: UUID?
  public var failedCount: Int
  public var isRunning: Bool

  public init(
    totalCount: Int,
    completedCount: Int,
    remainingCount: Int? = nil,
    currentEntryID: UUID? = nil,
    failedCount: Int = 0,
    isRunning: Bool
  ) {
    self.totalCount = totalCount
    self.completedCount = completedCount
    self.remainingCount = remainingCount ?? max(totalCount - completedCount, 0)
    self.currentEntryID = currentEntryID
    self.failedCount = failedCount
    self.isRunning = isRunning
  }

  public var fractionCompleted: Double {
    guard totalCount > 0 else { return 0 }
    return Double(completedCount) / Double(totalCount)
  }
}

/// Reanalyzes stored analyses that are missing the normalized full payload.
///
/// This keeps existing analysis ids so feedback remains linked, while replacing projection-only rows
/// with a complete `StoredDecisionAnalysis` graph generated from the current diary entry.
public struct ReanalyzeIncompleteAnalysesUseCase: Sendable {
  private let vault: DiaryVault
  private let analysisGenerator: EntryAnalysisGenerating

  init(vault: DiaryVault, analysisGenerator: EntryAnalysisGenerating) {
    self.vault = vault
    self.analysisGenerator = analysisGenerator
  }

  public func callAsFunction(
    onProgress: (@Sendable (ReanalyzeIncompleteAnalysesProgress) async -> Void)? = nil
  ) async throws -> ReanalyzeIncompleteAnalysesResult {
    let snapshot = try vault.snapshot()
    let pending = snapshot.entries.compactMap { entry -> (StoredDiaryEntry, StoredDecisionAnalysis)? in
      guard let analysis = snapshot.latestAnalyses[entry.id],
            analysis.needsReanalysis else {
        return nil
      }
      return (entry, analysis)
    }

    var completedCount = 0
    var updatedCount = 0
    var failedCount = 0
    await onProgress?(ReanalyzeIncompleteAnalysesProgress(
      totalCount: pending.count,
      completedCount: completedCount,
      failedCount: failedCount,
      isRunning: !pending.isEmpty
    ))

    for item in pending {
      await onProgress?(ReanalyzeIncompleteAnalysesProgress(
        totalCount: pending.count,
        completedCount: completedCount,
        currentEntryID: item.0.id,
        failedCount: failedCount,
        isRunning: true
      ))

      do {
        let analysis = try await analysisGenerator.analysis(
          for: item.0.makeEntryDraftCommand(),
          entryID: item.0.id
        )
        try vault.saveAnalysis(
          try analysis
            .replacingIdentity(id: item.1.id, entryID: item.0.id, createdAt: item.1.createdAt)
            .storedModel()
        )
        updatedCount += 1
      } catch {
        failedCount += 1
      }

      completedCount += 1
      await onProgress?(ReanalyzeIncompleteAnalysesProgress(
        totalCount: pending.count,
        completedCount: completedCount,
        failedCount: failedCount,
        isRunning: completedCount < pending.count
      ))
    }

    return ReanalyzeIncompleteAnalysesResult(
      snapshot: try LoadDiarySnapshotUseCase(vault: vault)(),
      updatedCount: updatedCount,
      failedCount: failedCount
    )
  }
}

private extension StoredDecisionAnalysis {
  var needsReanalysis: Bool {
    schemaVersion < Self.currentSchemaVersion || !hasFullAnalysisPayload
  }
}
