import DecisionKernel
import DiaryVault
import Foundation

@MainActor
final class DilemmaAppModel: ObservableObject {
  @Published private(set) var entries: [DiaryEntryRecord] = []
  @Published private(set) var latestAnalyses: [UUID: StoredDecisionAnalysis] = [:]
  @Published private(set) var statistics = PreferenceStatistics(
    entryCount: 0,
    feedbackCount: 0,
    acceptedConflictCount: 0,
    rejectedConflictCount: 0,
    mostFrequentClusters: [],
    chosenOptionCounts: [:]
  )
  @Published var errorMessage: String?
  @Published var isBusy = false

  private let vault: DiaryVault
  private let runAnalysis: RunDecisionAnalysisUseCase

  init(
    vault: DiaryVault = DiaryVault(),
    runAnalysis: RunDecisionAnalysisUseCase = RunDecisionAnalysisUseCase()
  ) {
    self.vault = vault
    self.runAnalysis = runAnalysis
  }

  func prepare() {
    do {
      try vault.prepare()
      try reload()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func reload() throws {
    let entries = try vault.entries()
    self.entries = entries
    var latest: [UUID: StoredDecisionAnalysis] = [:]
    for entry in entries {
      latest[entry.id] = try vault.analyses(entryID: entry.id).first
    }
    latestAnalyses = latest
    statistics = try vault.statistics()
  }

  func createAnalyzeAndSave(_ input: EntryFormInput) async {
    isBusy = true
    errorMessage = nil
    defer { isBusy = false }

    do {
      let now = Date()
      var entry = input.makeEntry(createdAt: now)
      try vault.saveEntry(entry)

      let draft = input.makeDraft(id: entry.id)
      let analysis = try await runAnalysis(draft)
      let storedAnalysis = StoredDecisionAnalysis(analysis: analysis, entryID: entry.id)
      try vault.saveAnalysis(storedAnalysis)

      entry.updatedAt = Date()
      try vault.saveEntry(entry)
      try reload()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func latestAnalysis(for entry: DiaryEntryRecord) -> StoredDecisionAnalysis? {
    latestAnalyses[entry.id]
  }
}

struct EntryFormInput: Equatable {
  var rawText = ""
  var option1Title = ""
  var option2Title = ""
  var option1Benefits = Array(repeating: "", count: 3)
  var option1Costs = Array(repeating: "", count: 3)
  var option2Benefits = Array(repeating: "", count: 3)
  var option2Costs = Array(repeating: "", count: 3)

  var isValid: Bool {
    !rawText.trimmed.isEmpty
      && !option1Title.trimmed.isEmpty
      && !option2Title.trimmed.isEmpty
      && option1Benefits.allSatisfy { !$0.trimmed.isEmpty }
      && option1Costs.allSatisfy { !$0.trimmed.isEmpty }
      && option2Benefits.allSatisfy { !$0.trimmed.isEmpty }
      && option2Costs.allSatisfy { !$0.trimmed.isEmpty }
  }

  func makeEntry(createdAt: Date = Date()) -> DiaryEntryRecord {
    DiaryEntryRecord(
      rawText: rawText.trimmed,
      options: [
        StoredDecisionOption(
          index: 1,
          title: option1Title.trimmed,
          reasons: storedReasons(benefits: option1Benefits, costs: option1Costs)
        ),
        StoredDecisionOption(
          index: 2,
          title: option2Title.trimmed,
          reasons: storedReasons(benefits: option2Benefits, costs: option2Costs)
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

  private func storedReasons(benefits: [String], costs: [String]) -> [StoredReason] {
    benefits.map { StoredReason(text: $0.trimmed, polarity: .benefit) }
      + costs.map { StoredReason(text: $0.trimmed, polarity: .cost) }
  }

  private func kernelReasons(benefits: [String], costs: [String]) -> [Reason] {
    benefits.map { Reason(text: $0.trimmed, polarity: .benefit) }
      + costs.map { Reason(text: $0.trimmed, polarity: .cost) }
  }
}

extension StoredDecisionAnalysis {
  init(analysis: DecisionAnalysisResult, entryID: UUID) {
    self.init(
      entryID: entryID,
      assetVersion: analysis.assetVersion,
      modelID: analysis.modelName,
      sourceDOI: analysis.sourceDOI,
      attributeConflicts: analysis.conflictDimensions.enumerated().map { offset, conflict in
        StoredAttributeConflict(
          attributeName: conflict.attributeName,
          option1Score: Double(conflict.option1Score),
          option2Score: Double(conflict.option2Score),
          difference: Double(conflict.difference),
          rank: offset + 1
        )
      },
      clusterProfiles: analysis.clusterProfiles.flatMap { optionIndex, clusters in
        clusters.map {
          StoredClusterProfile(
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
}
