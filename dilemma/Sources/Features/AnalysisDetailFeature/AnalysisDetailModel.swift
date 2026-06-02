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
  private(set) var preferenceStatistics = PreferenceStatistics.empty
  var didSaveFeedback = false
  var exportURL: URL?
  var errorMessage: String?

  @ObservationIgnored private let saveFeedbackUseCase: SaveFeedbackUseCase
  @ObservationIgnored private let exportDilemmaDraft: ExportDilemmaDraftUseCase
  @ObservationIgnored private let loadPreferenceStatisticsUseCase: LoadPreferenceStatisticsUseCase
  @ObservationIgnored private let onFeedbackSaved: @MainActor () -> Void

  init(
    entry: DiaryEntry,
    analysis: DiaryAnalysis?,
    allEntries: [DiaryEntry] = [],
    latestAnalyses: [UUID: DiaryAnalysis] = [:],
    saveFeedback: SaveFeedbackUseCase,
    exportDilemmaDraft: ExportDilemmaDraftUseCase,
    loadPreferenceStatistics: LoadPreferenceStatisticsUseCase,
    onFeedbackSaved: @escaping @MainActor () -> Void
  ) {
    self.entry = entry
    self.analysis = analysis
    self.allEntries = allEntries
    self.latestAnalyses = latestAnalyses
    self.saveFeedbackUseCase = saveFeedback
    self.exportDilemmaDraft = exportDilemmaDraft
    self.loadPreferenceStatisticsUseCase = loadPreferenceStatistics
    self.onFeedbackSaved = onFeedbackSaved
    reloadPreferenceStatistics()
  }

  var canSaveFeedback: Bool {
    chosenOptionIndex != nil
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
      didSaveFeedback = true
      errorMessage = nil
      reloadPreferenceStatistics()
      onFeedbackSaved()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func prepareExportFile() {
    do {
      exportURL = try exportDilemmaDraft.makeTemporaryExportFile(entry: entry)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func reloadPreferenceStatistics() {
    do {
      preferenceStatistics = try loadPreferenceStatisticsUseCase()
    } catch {
      preferenceStatistics = .empty
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
        sharedClusterLabels: Self.sharedClusterLabels(
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

  private static func sharedClusterLabels(
    query: DiaryAnalysis,
    candidate: DiaryAnalysis,
    limit: Int
  ) -> [String] {
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
      .compactMap { labels[$0] }
  }
}

struct SimilarDilemma: Identifiable {
  var id: UUID { entry.id }
  let entry: DiaryEntry
  let score: Double
  let sharedClusterLabels: [String]
}
