import DecisionKernel
import DiaryVault
import Foundation

public struct EntryDraftCommand: Equatable, Sendable {
  public var rawText: String
  public var option1Title: String
  public var option2Title: String
  public var option1Benefits: [String]
  public var option1Costs: [String]
  public var option2Benefits: [String]
  public var option2Costs: [String]

  public init(
    rawText: String = "",
    option1Title: String = "",
    option2Title: String = "",
    option1Benefits: [String] = Array(repeating: "", count: 3),
    option1Costs: [String] = Array(repeating: "", count: 3),
    option2Benefits: [String] = Array(repeating: "", count: 3),
    option2Costs: [String] = Array(repeating: "", count: 3)
  ) {
    self.rawText = rawText
    self.option1Title = option1Title
    self.option2Title = option2Title
    self.option1Benefits = option1Benefits
    self.option1Costs = option1Costs
    self.option2Benefits = option2Benefits
    self.option2Costs = option2Costs
  }

  public var isValid: Bool {
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

public struct FeedbackCommand: Equatable, Sendable {
  public var entryID: UUID
  public var analysisID: UUID?
  public var conflictWasUseful: Bool
  public var correctedClusterID: Int?
  public var correctedAttributeName: String?
  public var chosenOptionIndex: Int?
  public var note: String

  public init(
    entryID: UUID,
    analysisID: UUID?,
    conflictWasUseful: Bool,
    correctedClusterID: Int? = nil,
    correctedAttributeName: String? = nil,
    chosenOptionIndex: Int? = nil,
    note: String = ""
  ) {
    self.entryID = entryID
    self.analysisID = analysisID
    self.conflictWasUseful = conflictWasUseful
    self.correctedClusterID = correctedClusterID
    self.correctedAttributeName = correctedAttributeName
    self.chosenOptionIndex = chosenOptionIndex
    self.note = note
  }
}

public struct DiarySnapshot: Equatable, Sendable {
  public var entries: [DiaryEntrySnapshot]
  public var latestAnalyses: [UUID: AnalysisSnapshot]

  public init(entries: [DiaryEntrySnapshot], latestAnalyses: [UUID: AnalysisSnapshot]) {
    self.entries = entries
    self.latestAnalyses = latestAnalyses
  }
}

public struct DiaryEntrySnapshot: Identifiable, Equatable, Sendable {
  public var id: UUID
  public var rawText: String
  public var options: [DecisionOptionSnapshot]
  public var createdAt: Date
  public var updatedAt: Date

  public init(id: UUID, rawText: String, options: [DecisionOptionSnapshot], createdAt: Date, updatedAt: Date) {
    self.id = id
    self.rawText = rawText
    self.options = options
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  init(entry: DiaryEntryRecord) {
    self.init(
      id: entry.id,
      rawText: entry.rawText,
      options: entry.options.map(DecisionOptionSnapshot.init(option:)),
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt
    )
  }
}

public struct DecisionOptionSnapshot: Identifiable, Equatable, Sendable {
  public var id: UUID
  public var index: Int
  public var title: String
  public var reasons: [ReasonSnapshot]

  public init(id: UUID, index: Int, title: String, reasons: [ReasonSnapshot]) {
    self.id = id
    self.index = index
    self.title = title
    self.reasons = reasons
  }

  init(option: StoredDecisionOption) {
    self.init(
      id: option.id,
      index: option.index,
      title: option.title,
      reasons: option.reasons.map(ReasonSnapshot.init(reason:))
    )
  }
}

public enum ReasonSnapshotPolarity: String, Equatable, Sendable {
  case benefit
  case cost
}

public struct ReasonSnapshot: Identifiable, Equatable, Sendable {
  public var id: UUID
  public var text: String
  public var polarity: ReasonSnapshotPolarity

  public init(id: UUID, text: String, polarity: ReasonSnapshotPolarity) {
    self.id = id
    self.text = text
    self.polarity = polarity
  }

  init(reason: StoredReason) {
    self.init(
      id: reason.id,
      text: reason.text,
      polarity: reason.polarity == .benefit ? .benefit : .cost
    )
  }
}

public struct AnalysisSnapshot: Identifiable, Equatable, Sendable {
  public var id: UUID
  public var entryID: UUID
  public var createdAt: Date
  public var assetVersion: Int
  public var modelID: String
  public var sourceDOI: String
  public var attributeConflicts: [AttributeConflictSnapshot]
  public var clusterProfiles: [ClusterProfileSnapshot]

  public init(
    id: UUID,
    entryID: UUID,
    createdAt: Date,
    assetVersion: Int,
    modelID: String,
    sourceDOI: String,
    attributeConflicts: [AttributeConflictSnapshot],
    clusterProfiles: [ClusterProfileSnapshot]
  ) {
    self.id = id
    self.entryID = entryID
    self.createdAt = createdAt
    self.assetVersion = assetVersion
    self.modelID = modelID
    self.sourceDOI = sourceDOI
    self.attributeConflicts = attributeConflicts
    self.clusterProfiles = clusterProfiles
  }

  init(analysis: StoredDecisionAnalysis) {
    self.init(
      id: analysis.id,
      entryID: analysis.entryID,
      createdAt: analysis.createdAt,
      assetVersion: analysis.assetVersion,
      modelID: analysis.modelID,
      sourceDOI: analysis.sourceDOI,
      attributeConflicts: analysis.attributeConflicts.map(AttributeConflictSnapshot.init(conflict:)),
      clusterProfiles: analysis.clusterProfiles.map(ClusterProfileSnapshot.init(profile:))
    )
  }
}

public struct AttributeConflictSnapshot: Identifiable, Equatable, Sendable {
  public var id: UUID
  public var attributeName: String
  public var option1Score: Double
  public var option2Score: Double
  public var difference: Double
  public var rank: Int

  public init(
    id: UUID,
    attributeName: String,
    option1Score: Double,
    option2Score: Double,
    difference: Double,
    rank: Int
  ) {
    self.id = id
    self.attributeName = attributeName
    self.option1Score = option1Score
    self.option2Score = option2Score
    self.difference = difference
    self.rank = rank
  }

  init(conflict: StoredAttributeConflict) {
    self.init(
      id: conflict.id,
      attributeName: conflict.attributeName,
      option1Score: conflict.option1Score,
      option2Score: conflict.option2Score,
      difference: conflict.difference,
      rank: conflict.rank
    )
  }
}

public struct ClusterProfileSnapshot: Identifiable, Equatable, Sendable {
  public var id: UUID
  public var optionIndex: Int
  public var clusterID: Int
  public var label: String
  public var score: Double

  public init(id: UUID, optionIndex: Int, clusterID: Int, label: String, score: Double) {
    self.id = id
    self.optionIndex = optionIndex
    self.clusterID = clusterID
    self.label = label
    self.score = score
  }

  init(profile: StoredClusterProfile) {
    self.init(
      id: profile.id,
      optionIndex: profile.optionIndex,
      clusterID: profile.clusterID,
      label: profile.label,
      score: profile.score
    )
  }
}

public struct PreferenceStatisticsSnapshot: Equatable, Sendable {
  public var entryCount: Int
  public var feedbackCount: Int
  public var acceptedConflictCount: Int
  public var rejectedConflictCount: Int
  public var mostFrequentClusters: [ClusterFrequencySnapshot]
  public var chosenOptionCounts: [Int: Int]

  public init(
    entryCount: Int,
    feedbackCount: Int,
    acceptedConflictCount: Int,
    rejectedConflictCount: Int,
    mostFrequentClusters: [ClusterFrequencySnapshot],
    chosenOptionCounts: [Int: Int]
  ) {
    self.entryCount = entryCount
    self.feedbackCount = feedbackCount
    self.acceptedConflictCount = acceptedConflictCount
    self.rejectedConflictCount = rejectedConflictCount
    self.mostFrequentClusters = mostFrequentClusters
    self.chosenOptionCounts = chosenOptionCounts
  }

  init(statistics: PreferenceStatistics) {
    self.init(
      entryCount: statistics.entryCount,
      feedbackCount: statistics.feedbackCount,
      acceptedConflictCount: statistics.acceptedConflictCount,
      rejectedConflictCount: statistics.rejectedConflictCount,
      mostFrequentClusters: statistics.mostFrequentClusters.map(ClusterFrequencySnapshot.init(cluster:)),
      chosenOptionCounts: statistics.chosenOptionCounts
    )
  }
}

public struct ClusterFrequencySnapshot: Identifiable, Equatable, Sendable {
  public var id: Int { clusterID }
  public var clusterID: Int
  public var label: String
  public var count: Int

  public init(clusterID: Int, label: String, count: Int) {
    self.clusterID = clusterID
    self.label = label
    self.count = count
  }

  init(cluster: ClusterFrequency) {
    self.init(clusterID: cluster.clusterID, label: cluster.label, count: cluster.count)
  }
}

extension EntryDraftCommand {
  static func sample() -> EntryDraftCommand {
    EntryDraftCommand(
      rawText: "Should I stay or leave?",
      option1Title: "Stay",
      option2Title: "Leave",
      option1Benefits: ["Stable income", "Close to family", "Lower risk"],
      option1Costs: ["Less growth", "Boredom", "Missed opportunity"],
      option2Benefits: ["Career growth", "New skills", "Independence"],
      option2Costs: ["Financial risk", "Stress", "Less family time"]
    )
  }
}

extension String {
  var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
