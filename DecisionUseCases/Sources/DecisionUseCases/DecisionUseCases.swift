import DecisionModels
import DecisionKernel
import DiaryVault
import Foundation

public struct DecisionUseCases: Sendable {
  public let prepareDiary: PrepareDiaryUseCase
  public let loadDiarySnapshot: LoadDiarySnapshotUseCase
  public let createAnalyzedEntry: CreateAnalyzedEntryUseCase
  public let saveFeedback: SaveFeedbackUseCase
  public let loadPreferenceStatistics: LoadPreferenceStatisticsUseCase
  public let exportDiaryData: ExportDiaryDataUseCase
  public let deleteDiaryData: DeleteDiaryDataUseCase
  public let unlockDiary: UnlockDiaryUseCase

  public static func live() -> DecisionUseCases {
    let vault = DiaryVault()
    return live(vault: vault)
  }

  static func live(vault: DiaryVault) -> DecisionUseCases {
    let analysisGenerator = LiveEntryAnalysisGenerator(runAnalysis: RunDecisionAnalysisUseCase())
    return DecisionUseCases(
      prepareDiary: PrepareDiaryUseCase(vault: vault),
      loadDiarySnapshot: LoadDiarySnapshotUseCase(vault: vault),
      createAnalyzedEntry: CreateAnalyzedEntryUseCase(vault: vault, analysisGenerator: analysisGenerator),
      saveFeedback: SaveFeedbackUseCase(vault: vault),
      loadPreferenceStatistics: LoadPreferenceStatisticsUseCase(vault: vault),
      exportDiaryData: ExportDiaryDataUseCase(vault: vault),
      deleteDiaryData: DeleteDiaryDataUseCase(vault: vault),
      unlockDiary: UnlockDiaryUseCase(vault: vault)
    )
  }

  static func testing(vault: DiaryVault, analysisGenerator: EntryAnalysisGenerating) -> DecisionUseCases {
    DecisionUseCases(
      prepareDiary: PrepareDiaryUseCase(vault: vault),
      loadDiarySnapshot: LoadDiarySnapshotUseCase(vault: vault),
      createAnalyzedEntry: CreateAnalyzedEntryUseCase(vault: vault, analysisGenerator: analysisGenerator),
      saveFeedback: SaveFeedbackUseCase(vault: vault),
      loadPreferenceStatistics: LoadPreferenceStatisticsUseCase(vault: vault),
      exportDiaryData: ExportDiaryDataUseCase(vault: vault),
      deleteDiaryData: DeleteDiaryDataUseCase(vault: vault),
      unlockDiary: UnlockDiaryUseCase(vault: vault)
    )
  }
}

struct RunDecisionAnalysisUseCase: Sendable {
  private let service: DecisionAnalysisService

  init(service: DecisionAnalysisService = DecisionAnalysisService()) {
    self.service = service
  }

  func callAsFunction(_ draft: DecisionDraft) async throws -> DecisionAnalysisResult {
    try await service.analyze(draft)
  }

  func callAsFunction() async throws -> DecisionAnalysisResult {
    try await DecisionAnalysisRunner().run()
  }
}

public struct PrepareDiaryUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction() throws {
    try vault.prepare()
  }
}

public struct UnlockDiaryUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction(reason: String = "Unlock your private decision diary.") async throws {
    try await vault.unlock(reason: reason)
  }
}

public struct LoadDiarySnapshotUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction() throws -> DiarySnapshot {
    let entries = try vault.entries()
    var latestAnalyses: [UUID: DiaryAnalysis] = [:]
    for entry in entries {
      if let analysis = try vault.analyses(entryID: entry.id).first {
        latestAnalyses[entry.id] = analysis
      }
    }
    return DiarySnapshot(
      entries: entries,
      latestAnalyses: latestAnalyses
    )
  }
}

public struct CreateAnalyzedEntryUseCase: Sendable {
  private let vault: DiaryVault
  private let analysisGenerator: EntryAnalysisGenerating

  init(vault: DiaryVault, analysisGenerator: EntryAnalysisGenerating) {
    self.vault = vault
    self.analysisGenerator = analysisGenerator
  }

  public func callAsFunction(_ command: EntryDraftCommand) async throws -> DiarySnapshot {
    let now = Date()
    var entry = command.makeEntry(createdAt: now)
    try vault.saveEntry(entry)

    let analysis = try await analysisGenerator.analysis(for: command, entryID: entry.id)
    try vault.saveAnalysis(analysis)

    entry.updatedAt = Date()
    try vault.saveEntry(entry)

    return try LoadDiarySnapshotUseCase(vault: vault)()
  }
}

public struct SaveFeedbackUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction(_ command: FeedbackCommand) throws {
    try vault.saveFeedback(
      Feedback(
        entryID: command.entryID,
        analysisID: command.analysisID,
        conflictWasUseful: command.conflictWasUseful,
        correctedClusterID: command.correctedClusterID,
        correctedAttributeName: command.correctedAttributeName?.trimmed.nilIfEmpty,
        chosenOptionIndex: command.chosenOptionIndex,
        note: command.note.trimmed
      )
    )
  }
}

public struct LoadPreferenceStatisticsUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction() throws -> PreferenceStatistics {
    try vault.statistics()
  }
}

public struct ExportDiaryDataUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction() throws -> Data {
    try vault.exportJSONData()
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

public struct DeleteDiaryDataUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction() throws {
    try vault.deleteAllData()
  }
}

protocol EntryAnalysisGenerating: Sendable {
  func analysis(for command: EntryDraftCommand, entryID: UUID) async throws -> DiaryAnalysis
}

struct LiveEntryAnalysisGenerator: EntryAnalysisGenerating {
  let runAnalysis: RunDecisionAnalysisUseCase

  func analysis(for command: EntryDraftCommand, entryID: UUID) async throws -> DiaryAnalysis {
    let analysis = try await runAnalysis(command.makeDraft(id: entryID))
    return DiaryAnalysis(analysis: analysis, entryID: entryID)
  }
}

private extension EntryDraftCommand {
  func makeEntry(createdAt: Date = Date()) -> DiaryEntry {
    DiaryEntry(
      rawText: rawText.trimmed,
      options: [
        DiaryOption(
          index: 1,
          title: option1Title.trimmed,
          reasons: diaryReasons(benefits: option1Benefits, costs: option1Costs)
        ),
        DiaryOption(
          index: 2,
          title: option2Title.trimmed,
          reasons: diaryReasons(benefits: option2Benefits, costs: option2Costs)
        ),
      ],
      createdAt: createdAt,
      updatedAt: createdAt
    )
  }

  func makeDraft(id: UUID) -> DecisionDraft {
    DecisionDraft(
      id: id,
      rawText: rawText.trimmed,
      options: [
        DecisionOption(
          index: 1,
          title: option1Title.trimmed,
          reasons: kernelReasons(benefits: option1Benefits, costs: option1Costs)
        ),
        DecisionOption(
          index: 2,
          title: option2Title.trimmed,
          reasons: kernelReasons(benefits: option2Benefits, costs: option2Costs)
        ),
      ]
    )
  }

  private func diaryReasons(benefits: [String], costs: [String]) -> [DiaryReason] {
    benefits.map { DiaryReason(text: $0.trimmed, polarity: .benefit) }
      + costs.map { DiaryReason(text: $0.trimmed, polarity: .cost) }
  }

  private func kernelReasons(benefits: [String], costs: [String]) -> [Reason] {
    benefits.map { Reason(text: $0.trimmed, polarity: .benefit) }
      + costs.map { Reason(text: $0.trimmed, polarity: .cost) }
  }
}

private extension DiaryAnalysis {
  init(analysis: DecisionAnalysisResult, entryID: UUID) {
    self.init(
      entryID: entryID,
      assetVersion: analysis.assetVersion,
      modelID: analysis.modelName,
      sourceDOI: analysis.sourceDOI,
      attributeConflicts: analysis.conflictDimensions.enumerated().map { offset, conflict in
        AttributeConflict(
          attributeName: conflict.attributeName,
          option1Score: Double(conflict.option1Score),
          option2Score: Double(conflict.option2Score),
          difference: Double(conflict.difference),
          rank: offset + 1
        )
      },
      clusterProfiles: analysis.clusterProfiles.flatMap { optionIndex, clusters in
        clusters.map {
          ClusterProfile(
            optionIndex: optionIndex,
            clusterID: $0.cluster.clusterID,
            label: $0.cluster.label,
            score: Double($0.score)
          )
        }
      }
    )
  }
}

private extension String {
  var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
