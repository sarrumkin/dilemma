import Foundation

/// Previously decided analysis paired with the option the user actually chose.
/// Recommendation logic uses these records as evidence for mapping past preferences onto a current dilemma.
public struct SimilarDecidedChoice: Equatable, Sendable {
  public var analysis: DecisionAnalysis
  public var chosenOptionIndex: Int

  public init(analysis: DecisionAnalysis, chosenOptionIndex: Int) {
    self.analysis = analysis
    self.chosenOptionIndex = chosenOptionIndex
  }
}

/// Advice about which current option looks more likely based on similar past decisions.
/// This is an advisory aggregate, not a choice made by the app on the user's behalf.
/// It keeps support values and per-option weights so UI can show confidence instead of only a hard answer.
public struct LikelyChoiceAdvice: Equatable, Sendable {
  public var optionIndex: Int?
  public var support: Double
  public var decidedDilemmaCount: Int
  public var optionWeights: [Int: Double]
  public var supportByOption: [Int: Double]

  public init(
    optionIndex: Int?,
    support: Double,
    decidedDilemmaCount: Int,
    optionWeights: [Int: Double],
    supportByOption: [Int: Double]
  ) {
    self.optionIndex = optionIndex
    self.support = support
    self.decidedDilemmaCount = decidedDilemmaCount
    self.optionWeights = optionWeights
    self.supportByOption = supportByOption
  }

  public init?(
    currentAnalysis: DecisionAnalysis,
    currentOptionIndices: [Int],
    decidedChoices: [SimilarDecidedChoice],
    limit: Int = 5
  ) {
    let optionIndices = Array(Set(currentOptionIndices)).sorted()
    guard !optionIndices.isEmpty, limit > 0 else { return nil }

    let rankedChoices = decidedChoices.enumerated().compactMap { offset, choice -> RankedChoice? in
      guard
        let similarity = Self.conflictSimilarity(
          between: currentAnalysis,
          and: choice.analysis
        ),
        similarity > Self.epsilon
      else {
        return nil
      }

      return RankedChoice(offset: offset, choice: choice, similarity: similarity)
    }
    .sorted {
      if abs($0.similarity - $1.similarity) <= Self.epsilon {
        return $0.offset < $1.offset
      }
      return $0.similarity > $1.similarity
    }
    .prefix(limit)

    var optionWeights = Dictionary(uniqueKeysWithValues: optionIndices.map { ($0, 0.0) })
    var contributingDilemmaCount = 0
    for rankedChoice in rankedChoices {
      let sideSource = Self.sideSource(
        currentAnalysis: currentAnalysis,
        decidedAnalysis: rankedChoice.choice.analysis
      )
      guard
        let currentSideVectors = Self.normalizedSideVectors(
          for: currentAnalysis,
          optionIndices: optionIndices,
          source: sideSource
        ),
        let chosenSideVector = Self.normalizedSideVector(
          for: rankedChoice.choice.analysis,
          optionIndex: rankedChoice.choice.chosenOptionIndex,
          source: sideSource
        ),
        let mappedOption = Self.bestMatchingSide(
          chosenSideVector: chosenSideVector,
          currentSideVectors: currentSideVectors
        )
      else {
        continue
      }

      optionWeights[mappedOption.optionIndex, default: 0] +=
        rankedChoice.similarity * mappedOption.similarity
      contributingDilemmaCount += 1
    }

    let totalWeight = optionWeights.values.reduce(0, +)
    guard totalWeight > Self.epsilon else { return nil }

    let rankedWeights = optionWeights
      .filter { $0.value > Self.epsilon }
      .sorted {
        if abs($0.value - $1.value) <= Self.epsilon {
          return $0.key < $1.key
        }
        return $0.value > $1.value
      }
    guard let top = rankedWeights.first else { return nil }

    let support = top.value / totalWeight
    guard support.isFinite else { return nil }
    let supportByOption = optionWeights.mapValues { weight in
      weight / totalWeight
    }
    let hasTiedLeader = rankedWeights.dropFirst().first.map { runnerUp in
      abs(top.value - runnerUp.value) <= Self.epsilon
    } ?? false
    let optionIndex = hasTiedLeader ? nil : top.key

    self.init(
      optionIndex: optionIndex,
      support: support,
      decidedDilemmaCount: contributingDilemmaCount,
      optionWeights: optionWeights,
      supportByOption: supportByOption
    )
  }

  public static func conflictSimilarity(
    between lhs: DecisionAnalysis,
    and rhs: DecisionAnalysis
  ) -> Double? {
    guard
      let lhsVector = normalizedConflictVector(for: lhs),
      let rhsVector = normalizedConflictVector(for: rhs)
    else {
      return nil
    }

    let similarity = dot(lhsVector, rhsVector)
    return similarity.isFinite ? similarity : nil
  }

  private static let epsilon = 0.000_000_001
  private static let minimumSideSimilarity = 0.03

  private enum AxisKey: Hashable {
    case attribute(Int)
    case cluster(Int)
  }

  private enum SideSource {
    case attribute
    case cluster
  }

  private struct RankedChoice {
    var offset: Int
    var choice: SimilarDecidedChoice
    var similarity: Double
  }

  private static func normalizedConflictVector(for analysis: DecisionAnalysis) -> [Int: Double]? {
    let option1 = clusterScores(for: analysis, optionIndex: 1)
    let option2 = clusterScores(for: analysis, optionIndex: 2)
    let clusterIDs = Set(option1.keys).union(option2.keys)
    let pairs: [(Int, Double)] = clusterIDs.compactMap { clusterID in
      let value = abs((option1[clusterID] ?? 0) - (option2[clusterID] ?? 0))
      guard value > epsilon else { return nil }
      return (clusterID, value)
    }
    return normalized(Dictionary(uniqueKeysWithValues: pairs))
  }

  private static func sideSource(
    currentAnalysis: DecisionAnalysis,
    decidedAnalysis: DecisionAnalysis
  ) -> SideSource {
    if signedAttributeAxis(for: currentAnalysis) != nil,
       signedAttributeAxis(for: decidedAnalysis) != nil {
      return .attribute
    }
    return .cluster
  }

  private static func normalizedSideVectors(
    for analysis: DecisionAnalysis,
    optionIndices: [Int],
    source: SideSource
  ) -> [Int: [AxisKey: Double]]? {
    guard let axis = normalizedSignedAxis(for: analysis, source: source) else { return nil }

    var vectors: [Int: [AxisKey: Double]] = [:]
    for optionIndex in optionIndices {
      switch optionIndex {
      case 1:
        vectors[optionIndex] = axis
      case 2:
        vectors[optionIndex] = negated(axis)
      default:
        continue
      }
    }
    return vectors.isEmpty ? nil : vectors
  }

  private static func normalizedSideVector(
    for analysis: DecisionAnalysis,
    optionIndex: Int,
    source: SideSource
  ) -> [AxisKey: Double]? {
    guard let axis = normalizedSignedAxis(for: analysis, source: source) else { return nil }

    switch optionIndex {
    case 1:
      return axis
    case 2:
      return negated(axis)
    default:
      return nil
    }
  }

  private static func normalizedSignedAxis(
    for analysis: DecisionAnalysis,
    source: SideSource
  ) -> [AxisKey: Double]? {
    switch source {
    case .attribute:
      return signedAttributeAxis(for: analysis)
    case .cluster:
      return signedClusterAxis(for: analysis)
    }
  }

  private static func signedAttributeAxis(for analysis: DecisionAnalysis) -> [AxisKey: Double]? {
    guard
      analysis.hasStoredEmbeddings,
      let option1 = attributeScores(for: analysis, optionIndex: 1),
      let option2 = attributeScores(for: analysis, optionIndex: 2)
    else {
      return nil
    }

    let attributeIDs = Set(option1.keys).union(option2.keys)
    let pairs: [(AxisKey, Double)] = attributeIDs.compactMap { attributeID in
      let value = Double(option1[attributeID] ?? 0) - Double(option2[attributeID] ?? 0)
      guard abs(value) > epsilon else { return nil }
      return (.attribute(attributeID), value)
    }
    return normalized(Dictionary(uniqueKeysWithValues: pairs))
  }

  private static func attributeScores(for analysis: DecisionAnalysis, optionIndex: Int) -> [Int: Float]? {
    guard let profile = analysis.optionAttributeProfiles.first(where: { $0.optionIndex == optionIndex }) else {
      return nil
    }

    let pairs: [(Int, Float)] = profile.scores.compactMap { score in
      guard abs(score.score) > Float(epsilon) else { return nil }
      return (score.attribute.attributeID, score.score)
    }
    let scores = Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    return scores.isEmpty ? nil : scores
  }

  private static func signedClusterAxis(for analysis: DecisionAnalysis) -> [AxisKey: Double]? {
    let option1 = clusterScores(for: analysis, optionIndex: 1)
    let option2 = clusterScores(for: analysis, optionIndex: 2)
    let clusterIDs = Set(option1.keys).union(option2.keys)
    let pairs: [(AxisKey, Double)] = clusterIDs.compactMap { clusterID in
      let value = (option1[clusterID] ?? 0) - (option2[clusterID] ?? 0)
      guard abs(value) > epsilon else { return nil }
      return (.cluster(clusterID), value)
    }
    return normalized(Dictionary(uniqueKeysWithValues: pairs))
  }

  private static func clusterScores(for analysis: DecisionAnalysis, optionIndex: Int) -> [Int: Double] {
    let pairs: [(Int, Double)] = analysis.clusterProfiles
      .filter { $0.optionIndex == optionIndex && abs($0.score) > epsilon }
      .map { ($0.clusterID, $0.score) }
    return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
  }

  private static func normalized<Key: Hashable>(_ vector: [Key: Double]) -> [Key: Double]? {
    let magnitude = sqrt(vector.values.reduce(0) { $0 + ($1 * $1) })
    guard magnitude > epsilon else { return nil }
    return vector.mapValues { $0 / magnitude }
  }

  private static func negated<Key: Hashable>(_ vector: [Key: Double]) -> [Key: Double] {
    vector.mapValues { -$0 }
  }

  private static func bestMatchingSide(
    chosenSideVector: [AxisKey: Double],
    currentSideVectors: [Int: [AxisKey: Double]]
  ) -> (optionIndex: Int, similarity: Double)? {
    let matches = currentSideVectors.map { optionIndex, currentSideVector in
      (optionIndex: optionIndex, similarity: dot(chosenSideVector, currentSideVector))
    }
    .filter { $0.similarity > minimumSideSimilarity }
    .sorted {
      if abs($0.similarity - $1.similarity) <= epsilon {
        return $0.optionIndex < $1.optionIndex
      }
      return $0.similarity > $1.similarity
    }

    guard let best = matches.first else { return nil }
    if matches.count > 1 && abs(best.similarity - matches[1].similarity) <= epsilon {
      return nil
    }
    return best
  }

  private static func dot<Key: Hashable>(_ lhs: [Key: Double], _ rhs: [Key: Double]) -> Double {
    lhs.reduce(0) { total, pair in
      total + (pair.value * (rhs[pair.key] ?? 0))
    }
  }
}

private extension DecisionAnalysis {
  var hasStoredEmbeddings: Bool {
    embeddings.dilemmaText.dimension > 0
      && embeddings.dilemmaText.values.count == embeddings.dilemmaText.dimension
      && embeddings.options.contains { option in
        option.embedding.dimension > 0
          && option.embedding.values.count == option.embedding.dimension
      }
      && embeddings.reasons.contains { reason in
        reason.embedding.dimension > 0
          && reason.embedding.values.count == reason.embedding.dimension
      }
  }
}
