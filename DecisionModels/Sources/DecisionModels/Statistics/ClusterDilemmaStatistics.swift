import Foundation

/// Groups analyzed diary entries by their strongest positive and negative clusters.
/// Statistics screens use it to explain recurring dilemma themes from saved analyses.
public struct ClusterDilemmaStatistics: Equatable, Sendable {
  public var analyzedEntryCount: Int
  public var groups: [ClusterDilemmaGroup]

  public init(analyzedEntryCount: Int, groups: [ClusterDilemmaGroup]) {
    self.analyzedEntryCount = analyzedEntryCount
    self.groups = groups
  }

  public init(snapshot: DiarySnapshot, clustersPerPolarity: Int = 3) {
    let clusterLimit = max(0, clustersPerPolarity)
    var recordsByClusterID: [Int: [UUID: ClusterDilemmaRecord]] = [:]
    var labelsByClusterID: [Int: String] = [:]
    var analyzedEntryCount = 0

    for entry in snapshot.entries {
      guard let analysis = snapshot.latestAnalyses[entry.id] else {
        continue
      }

      analyzedEntryCount += 1
      var entryRecordsByClusterID: [Int: ClusterDilemmaRecord] = [:]

      for option in entry.options {
        for profile in Self.relevantProfiles(
          for: analysis,
          optionIndex: option.index,
          limit: clusterLimit
        ) {
          labelsByClusterID[profile.clusterID] = profile.label
          let candidate = ClusterDilemmaRecord(
            entry: entry,
            analysis: analysis,
            optionIndices: [option.index],
            strongestScore: profile.score
          )

          if let existing = entryRecordsByClusterID[profile.clusterID] {
            entryRecordsByClusterID[profile.clusterID] = existing.merging(candidate)
          } else {
            entryRecordsByClusterID[profile.clusterID] = candidate
          }
        }
      }

      for (clusterID, record) in entryRecordsByClusterID {
        recordsByClusterID[clusterID, default: [:]][entry.id] = record
      }
    }

    let groups = recordsByClusterID.map { clusterID, recordsByEntryID in
      ClusterDilemmaGroup(
        clusterID: clusterID,
        label: labelsByClusterID[clusterID] ?? "Cluster \(clusterID)",
        records: recordsByEntryID.values.sorted(by: Self.recordSort)
      )
    }
    .sorted(by: Self.groupSort)

    self.init(analyzedEntryCount: analyzedEntryCount, groups: groups)
  }

  public static var empty: ClusterDilemmaStatistics {
    ClusterDilemmaStatistics(analyzedEntryCount: 0, groups: [])
  }

  private static func relevantProfiles(
    for analysis: DecisionAnalysis,
    optionIndex: Int,
    limit: Int
  ) -> [ClusterProfile] {
    guard limit > 0 else { return [] }

    let optionProfiles = analysis.clusterProfiles
      .filter { $0.optionIndex == optionIndex && $0.score != 0 }

    let positives = optionProfiles
      .filter { $0.score > 0 }
      .sorted { left, right in
        if left.score == right.score {
          return left.clusterID < right.clusterID
        }
        return left.score > right.score
      }
      .prefix(limit)

    let negatives = optionProfiles
      .filter { $0.score < 0 }
      .sorted { left, right in
        if left.score == right.score {
          return left.clusterID < right.clusterID
        }
        return left.score < right.score
      }
      .prefix(limit)

    return Array(positives) + Array(negatives)
  }

  private static func groupSort(_ lhs: ClusterDilemmaGroup, _ rhs: ClusterDilemmaGroup) -> Bool {
    if lhs.records.count == rhs.records.count {
      if lhs.label == rhs.label {
        return lhs.clusterID < rhs.clusterID
      }
      return lhs.label < rhs.label
    }
    return lhs.records.count > rhs.records.count
  }

  private static func recordSort(_ lhs: ClusterDilemmaRecord, _ rhs: ClusterDilemmaRecord) -> Bool {
    let leftMagnitude = abs(lhs.strongestScore)
    let rightMagnitude = abs(rhs.strongestScore)
    if leftMagnitude == rightMagnitude {
      return lhs.entry.updatedAt > rhs.entry.updatedAt
    }
    return leftMagnitude > rightMagnitude
  }
}

/// One cluster bucket in dilemma statistics.
/// It groups all entries where the same cluster is among the strongest analysis signals.
public struct ClusterDilemmaGroup: Identifiable, Equatable, Sendable {
  public var id: Int { clusterID }
  public var clusterID: Int
  public var label: String
  public var records: [ClusterDilemmaRecord]

  public var count: Int {
    records.count
  }

  public var strongestRecord: ClusterDilemmaRecord? {
    records.first
  }

  public init(clusterID: Int, label: String, records: [ClusterDilemmaRecord]) {
    self.clusterID = clusterID
    self.label = label
    self.records = records
  }
}

/// One diary entry's contribution to a cluster statistics group.
/// It records which option sides matched the cluster and the strongest score used for sorting.
public struct ClusterDilemmaRecord: Identifiable, Equatable, Sendable {
  public var id: UUID { entry.id }
  public var entry: DiaryEntry
  public var analysis: DecisionAnalysis
  public var optionIndices: [Int]
  public var strongestScore: Double

  public init(
    entry: DiaryEntry,
    analysis: DecisionAnalysis,
    optionIndices: [Int],
    strongestScore: Double
  ) {
    self.entry = entry
    self.analysis = analysis
    self.optionIndices = optionIndices.sorted()
    self.strongestScore = strongestScore
  }

  fileprivate func merging(_ other: ClusterDilemmaRecord) -> ClusterDilemmaRecord {
    ClusterDilemmaRecord(
      entry: entry,
      analysis: analysis,
      optionIndices: Array(Set(optionIndices).union(other.optionIndices)).sorted(),
      strongestScore: Self.strongestScore(between: strongestScore, and: other.strongestScore)
    )
  }

  private static func strongestScore(between lhs: Double, and rhs: Double) -> Double {
    if abs(lhs) == abs(rhs) {
      return lhs >= rhs ? lhs : rhs
    }
    return abs(lhs) > abs(rhs) ? lhs : rhs
  }
}
