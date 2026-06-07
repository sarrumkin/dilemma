import DecisionModels
import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class AnalysisDetailModel {
  let entry: DiaryEntry
  let analysis: DiaryAnalysis?
  let allEntries: [DiaryEntry]
  let latestAnalyses: [UUID: DiaryAnalysis]
  var chosenOptionIndex: Int?
  var note = ""
  private(set) var savedFeedback: Feedback?
  private(set) var isEditingFeedback = false
  private(set) var preferenceStatistics = PreferenceStatistics.empty
  var didSaveFeedback = false
  var exportURL: URL?
  var errorMessage: String?

  @ObservationIgnored private let saveFeedbackUseCase: SaveFeedbackUseCase
  @ObservationIgnored private let loadFeedbackForAnalysisUseCase: LoadFeedbackForAnalysisUseCase
  @ObservationIgnored private let exportDilemmaDraft: ExportDilemmaDraftUseCase
  @ObservationIgnored private let loadPreferenceStatisticsUseCase: LoadPreferenceStatisticsUseCase
  @ObservationIgnored private let onFeedbackSaved: @MainActor () -> Void

  init(
    entry: DiaryEntry,
    analysis: DiaryAnalysis?,
    allEntries: [DiaryEntry] = [],
    latestAnalyses: [UUID: DiaryAnalysis] = [:],
    saveFeedback: SaveFeedbackUseCase,
    loadFeedbackForAnalysis: LoadFeedbackForAnalysisUseCase,
    exportDilemmaDraft: ExportDilemmaDraftUseCase,
    loadPreferenceStatistics: LoadPreferenceStatisticsUseCase,
    onFeedbackSaved: @escaping @MainActor () -> Void
  ) {
    self.entry = entry
    self.analysis = analysis
    self.allEntries = allEntries
    self.latestAnalyses = latestAnalyses
    self.saveFeedbackUseCase = saveFeedback
    self.loadFeedbackForAnalysisUseCase = loadFeedbackForAnalysis
    self.exportDilemmaDraft = exportDilemmaDraft
    self.loadPreferenceStatisticsUseCase = loadPreferenceStatistics
    self.onFeedbackSaved = onFeedbackSaved
    reloadSavedFeedback()
    reloadPreferenceStatistics()
  }

  var canSaveFeedback: Bool {
    analysis != nil && isEditingFeedback && (chosenOptionIndex != nil || hasSavedFeedback)
  }

  var hasSavedFeedback: Bool {
    savedFeedback != nil
  }

  var savedDecisionTitle: String {
    optionTitle(for: savedFeedback?.chosenOptionIndex)
  }

  var savedNote: String {
    savedFeedback?.note ?? ""
  }

  var saveFeedbackButtonTitle: String {
    hasSavedFeedback ? "Save changes" : "Save decision"
  }

  var topChosenCluster: ClusterFrequency? {
    preferenceStatistics.mostFrequentClusters.first
  }

  var chosenClusterDilemmaCount: Int {
    preferenceStatistics.chosenClusterDilemmaCount
  }

  func saveFeedback() {
    guard let analysis, canSaveFeedback else { return }
    do {
      try saveFeedbackUseCase(
        FeedbackCommand(
          entryID: entry.id,
          analysisID: analysis.id,
          conflictWasUseful: true,
          chosenOptionIndex: chosenOptionIndex,
          note: note
        )
      )
      savedFeedback = try loadFeedbackForAnalysisUseCase(entryID: entry.id, analysisID: analysis.id)
      if savedFeedback == nil {
        chosenOptionIndex = nil
        note = ""
        isEditingFeedback = false
        didSaveFeedback = false
      } else {
        applySavedFeedback()
        isEditingFeedback = false
        didSaveFeedback = true
      }
      errorMessage = nil
      reloadPreferenceStatistics()
      onFeedbackSaved()
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .saveFeedback)
    }
  }

  func startEditingFeedback() {
    chosenOptionIndex = savedFeedback?.chosenOptionIndex
    note = savedFeedback?.note ?? ""
    isEditingFeedback = true
    didSaveFeedback = false
  }

  func cancelEditingFeedback() {
    applySavedFeedback()
    isEditingFeedback = false
    didSaveFeedback = false
  }

  func prepareExportFile() {
    do {
      exportURL = try exportDilemmaDraft.makeTemporaryExportFile(entry: entry, analysis: analysis)
      errorMessage = nil
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .exportEntry)
    }
  }

  func reloadPreferenceStatistics() {
    do {
      preferenceStatistics = try loadPreferenceStatisticsUseCase()
    } catch {
      preferenceStatistics = .empty
    }
  }

  func reloadSavedFeedback() {
    guard let analysis else {
      savedFeedback = nil
      chosenOptionIndex = nil
      note = ""
      isEditingFeedback = false
      return
    }

    do {
      savedFeedback = try loadFeedbackForAnalysisUseCase(entryID: entry.id, analysisID: analysis.id)
      if savedFeedback == nil {
        chosenOptionIndex = nil
        note = ""
        isEditingFeedback = false
      } else {
        applySavedFeedback()
        isEditingFeedback = false
      }
    } catch {
      savedFeedback = nil
      chosenOptionIndex = nil
      note = ""
      isEditingFeedback = false
    }
  }

  func similarDilemmas(limit: Int = 5) -> [SimilarDilemma] {
    guard
      let analysis,
      let queryVector = Self.normalizedConflictVector(for: analysis)
    else {
      return []
    }

    return allEntries.compactMap { candidateEntry in
      guard
        candidateEntry.id != entry.id,
        let candidateAnalysis = latestAnalyses[candidateEntry.id],
        let candidateVector = Self.normalizedConflictVector(for: candidateAnalysis)
      else {
        return nil
      }

      let score = Self.dot(queryVector, candidateVector)
      guard score.isFinite, score > 0 else { return nil }

      return SimilarDilemma(
        entry: candidateEntry,
        score: score,
        sharedClusters: Self.sharedClusters(
          query: analysis,
          candidate: candidateAnalysis,
          limit: 3
        )
      )
    }
    .sorted {
      if $0.score == $1.score {
        return $0.entry.updatedAt > $1.entry.updatedAt
      }
      return $0.score > $1.score
    }
    .prefix(limit)
    .map { $0 }
  }

  func makeSimilarDilemmaModel(for match: SimilarDilemma) -> AnalysisDetailModel {
    AnalysisDetailModel(
      entry: match.entry,
      analysis: latestAnalyses[match.entry.id],
      allEntries: allEntries,
      latestAnalyses: latestAnalyses,
      saveFeedback: saveFeedbackUseCase,
      loadFeedbackForAnalysis: loadFeedbackForAnalysisUseCase,
      exportDilemmaDraft: exportDilemmaDraft,
      loadPreferenceStatistics: loadPreferenceStatisticsUseCase,
      onFeedbackSaved: onFeedbackSaved
    )
  }

  private static func normalizedConflictVector(for analysis: DiaryAnalysis) -> [Int: Double]? {
    let option1 = clusterScores(for: analysis, optionIndex: 1)
    let option2 = clusterScores(for: analysis, optionIndex: 2)
    let clusterIDs = Set(option1.keys).union(option2.keys)
    let pairs: [(Int, Double)] = clusterIDs.compactMap { clusterID in
      let value = abs((option1[clusterID] ?? 0) - (option2[clusterID] ?? 0))
      guard value > 0 else { return nil }
      return (clusterID, value)
    }
    let vector = Dictionary(uniqueKeysWithValues: pairs)
    let magnitude = sqrt(vector.values.reduce(0) { $0 + ($1 * $1) })
    guard magnitude > 0 else { return nil }
    return vector.mapValues { $0 / magnitude }
  }

  private static func clusterScores(for analysis: DiaryAnalysis, optionIndex: Int) -> [Int: Double] {
    let pairs: [(Int, Double)] = analysis.clusterProfiles
      .filter { $0.optionIndex == optionIndex }
      .map { ($0.clusterID, $0.score) }
    return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
  }

  private static func dot(_ lhs: [Int: Double], _ rhs: [Int: Double]) -> Double {
    lhs.reduce(0) { total, pair in
      total + (pair.value * (rhs[pair.key] ?? 0))
    }
  }

  private static func sharedClusters(
    query: DiaryAnalysis,
    candidate: DiaryAnalysis,
    limit: Int
  ) -> [SharedCluster] {
    guard
      let queryVector = normalizedConflictVector(for: query),
      let candidateVector = normalizedConflictVector(for: candidate)
    else {
      return []
    }

    let labelPairs: [(Int, String)] = (query.clusterProfiles + candidate.clusterProfiles)
      .map { ($0.clusterID, $0.label) }
    let labels = Dictionary(labelPairs, uniquingKeysWith: { first, _ in first })

    return queryVector.keys
      .filter { candidateVector[$0] != nil }
      .sorted {
        let left = (queryVector[$0] ?? 0) * (candidateVector[$0] ?? 0)
        let right = (queryVector[$1] ?? 0) * (candidateVector[$1] ?? 0)
        if left == right {
          return $0 < $1
        }
        return left > right
      }
      .prefix(limit)
      .map { clusterID in
        SharedCluster(
          clusterID: clusterID,
          label: labels[clusterID] ?? "Cluster \(clusterID)"
        )
      }
  }

  private func applySavedFeedback() {
    chosenOptionIndex = savedFeedback?.chosenOptionIndex
    note = savedFeedback?.note ?? ""
  }

  private func optionTitle(for optionIndex: Int?) -> String {
    guard let optionIndex else { return "Not decided yet" }
    return entry.options.first { $0.index == optionIndex }?.title ?? "Option \(optionIndex)"
  }
}

struct SimilarDilemma: Identifiable {
  var id: UUID { entry.id }
  let entry: DiaryEntry
  let score: Double
  let sharedClusters: [SharedCluster]
}

struct SharedCluster: Identifiable {
  var id: Int { clusterID }
  let clusterID: Int
  let label: String
}
