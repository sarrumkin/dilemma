import Foundation
import Testing

@testable import DecisionKernel
@testable import DecisionModels

/// Regression for likely-choice advice using real analysis output, not saved fixture analysis.
@Suite
struct LikelyChoiceRecommendationRegressionTests {
  private static let modelResourceName = "paraphrase-multilingual-MiniLM-L12-v2"

  private static var requiredResourcesAvailable: Bool {
    let bundle = DecisionKernelResourceBundle.bundle
    let modelURL = bundle.url(
      forResource: modelResourceName,
      withExtension: nil,
      subdirectory: "Models"
    )
    let assetURL = bundle.url(
      forResource: DecisionClusterMethod.bhatiaWardReddit.assetResourceName,
      withExtension: "sqlite",
      subdirectory: "Attributes"
    )
    return modelURL != nil && assetURL != nil
  }

  @Test(
    .enabled(
      if: Self.requiredResourcesAvailable,
      "Bundled multilingual MiniLM model folder or Bhatia SQLite asset is not present."
    )
  )
  func socksAdviceIsAmbiguousForBikeSpeedAndReportQualityChoices() async throws {
    let fixture = try Self.loadFixture()
    let socksDraft = try #require(fixture["quality_vs_speed-socks"])
    let bikeDraft = try #require(fixture["quality_vs_speed-bike-repair"])
    let reportDraft = try #require(fixture["quality_vs_speed-work-report"])

    let service = DecisionAnalysisService(clusterMethod: .bhatiaWardReddit)
    let socksAnalysis = try await Self.analyze(socksDraft, using: service)
    let bikeAnalysis = try await Self.analyze(bikeDraft, using: service)
    let reportAnalysis = try await Self.analyze(reportDraft, using: service)

    Self.printDiagnostics(id: "quality_vs_speed-socks", analysis: socksAnalysis)
    Self.printDiagnostics(id: "quality_vs_speed-bike-repair", analysis: bikeAnalysis)
    Self.printDiagnostics(id: "quality_vs_speed-work-report", analysis: reportAnalysis)
    Self.printRecommendationDiagnostics(
      currentID: "quality_vs_speed-socks",
      currentAnalysis: socksAnalysis,
      decidedChoices: [
        ("quality_vs_speed-bike-repair", bikeAnalysis, 2),
        ("quality_vs_speed-work-report", reportAnalysis, 1),
      ]
    )

    let advice = try #require(LikelyChoiceAdvice(
      currentAnalysis: socksAnalysis,
      currentOptionIndices: [1, 2],
      decidedChoices: [
        SimilarDecidedChoice(analysis: bikeAnalysis, chosenOptionIndex: 2),
        SimilarDecidedChoice(analysis: reportAnalysis, chosenOptionIndex: 1),
      ],
      limit: 2
    ))

    print("LIKELY_CHOICE_REGRESSION_OPTION_INDEX=\(String(describing: advice.optionIndex))")
    print("LIKELY_CHOICE_REGRESSION_SUPPORT=\(advice.support)")
    print("LIKELY_CHOICE_REGRESSION_WEIGHTS=\(advice.optionWeights)")
    print("LIKELY_CHOICE_REGRESSION_SUPPORT_BY_OPTION=\(advice.supportByOption)")

    #expect(advice.decidedDilemmaCount == 2)
    #expect(advice.optionIndex == nil)
    #expect((advice.optionWeights[1] ?? 0) > 0)
    #expect((advice.optionWeights[2] ?? 0) > 0)
    #expect(abs((advice.supportByOption[1] ?? 0) - 0.5) < 0.02)
    #expect(abs((advice.supportByOption[2] ?? 0) - 0.5) < 0.02)
  }

  private static func analyze(
    _ draft: DilemmaDraftJSON,
    using service: DecisionAnalysisService
  ) async throws -> DecisionAnalysis {
    return try await service.analyze(try draft.makeDecisionDraft())
  }

  private static func loadFixture() throws -> [String: DilemmaDraftJSON] {
    let data = try Data(contentsOf: fixtureURL())
    let fixture = try JSONDecoder().decode(RecommendationRegressionFixture.self, from: data)
    return Dictionary(uniqueKeysWithValues: fixture.dilemmas.map { ($0.id, $0.draft) })
  }

  private static func fixtureURL() throws -> URL {
    let bundle = Bundle(for: SimilarityExperimentResourceAnchor.self)
    let candidates = [
      bundle.url(
        forResource: "quality_vs_speed_socks_bike_report",
        withExtension: "json",
        subdirectory: "Resources/SimilarityExperiment/RecommendationRegression"
      ),
      bundle.url(
        forResource: "quality_vs_speed_socks_bike_report",
        withExtension: "json",
        subdirectory: "SimilarityExperiment/RecommendationRegression"
      ),
      bundle.url(
        forResource: "quality_vs_speed_socks_bike_report",
        withExtension: "json",
        subdirectory: "RecommendationRegression"
      ),
      bundle.url(forResource: "quality_vs_speed_socks_bike_report", withExtension: "json"),
    ]

    if let url = candidates.compactMap({ $0 }).first {
      return url
    }

    let checkedPaths = [
      "Resources/SimilarityExperiment/RecommendationRegression/quality_vs_speed_socks_bike_report.json",
      "SimilarityExperiment/RecommendationRegression/quality_vs_speed_socks_bike_report.json",
      "RecommendationRegression/quality_vs_speed_socks_bike_report.json",
      "quality_vs_speed_socks_bike_report.json",
    ]
    throw NSError(
      domain: "DecisionKernelTests.LikelyChoiceRecommendationRegressionTests",
      code: 1,
      userInfo: [
        NSLocalizedDescriptionKey:
          "quality_vs_speed_socks_bike_report.json was not found in test bundle. Checked: \(checkedPaths.joined(separator: ", "))",
      ]
    )
  }

  private static func printDiagnostics(id: String, analysis: DecisionAnalysis) {
    print("LIKELY_CHOICE_REGRESSION_ANALYSIS_ID=\(id)")
    for conflict in analysis.attributeConflicts.prefix(8) {
      print(
        "  ATTRIBUTE rank=\(conflict.rank) name=\(conflict.attributeName) o1=\(conflict.option1Score) o2=\(conflict.option2Score) axis=\(conflict.option1Score - conflict.option2Score)"
      )
    }

    for optionIndex in [1, 2] {
      let profiles = analysis.clusterProfiles
        .filter { $0.optionIndex == optionIndex }
        .sorted { abs($0.score) > abs($1.score) }
        .prefix(8)
      print("  OPTION \(optionIndex) CLUSTERS")
      for profile in profiles {
        print(
          "    clusterID=\(profile.clusterID) label=\(profile.label) score=\(profile.score)"
        )
      }
    }
  }

  private static func printRecommendationDiagnostics(
    currentID: String,
    currentAnalysis: DecisionAnalysis,
    decidedChoices: [(id: String, analysis: DecisionAnalysis, chosenOptionIndex: Int)]
  ) {
    for choice in decidedChoices {
      let source: DiagnosticSideSource =
        signedAttributeAxis(for: currentAnalysis) != nil
          && signedAttributeAxis(for: choice.analysis) != nil
        ? .attribute
        : .cluster
      guard
        let conflictSimilarity = conflictSimilarity(between: currentAnalysis, and: choice.analysis),
        let currentAxis = normalizedSignedAxis(for: currentAnalysis, source: source),
        let decidedAxis = normalizedSignedAxis(for: choice.analysis, source: source)
      else {
        print("LIKELY_CHOICE_REGRESSION_MATCH current=\(currentID) decided=\(choice.id) skipped")
        continue
      }

      let chosenSide = choice.chosenOptionIndex == 2 ? negated(decidedAxis) : decidedAxis
      let option1Similarity = dot(chosenSide, currentAxis)
      let option2Similarity = dot(chosenSide, negated(currentAxis))
      let bestOption = option1Similarity >= option2Similarity ? 1 : 2
      let bestSimilarity = max(option1Similarity, option2Similarity)
      let passesMinimumSideSimilarity = bestSimilarity > 0.03
      let weight = passesMinimumSideSimilarity ? conflictSimilarity * bestSimilarity : 0

      print(
        "LIKELY_CHOICE_REGRESSION_MATCH current=\(currentID) decided=\(choice.id) chosenOption=\(choice.chosenOptionIndex) source=\(source.rawValue) conflictSimilarity=\(conflictSimilarity) option1SideSimilarity=\(option1Similarity) option2SideSimilarity=\(option2Similarity) bestOption=\(bestOption) bestSimilarity=\(bestSimilarity) passesMinimumSideSimilarity=\(passesMinimumSideSimilarity) weight=\(weight)"
      )
      let contributions = chosenSide.map { key, value in
        (key: key, contribution: value * (currentAxis[key] ?? 0))
      }
      .filter { abs($0.contribution) > 0.000_000_001 }
      .sorted { abs($0.contribution) > abs($1.contribution) }
      .prefix(10)
      for contribution in contributions {
        print(
          "  MATCH_CONTRIBUTION decided=\(choice.id) key=\(contribution.key.description) value=\(contribution.contribution)"
        )
      }
    }
  }

  private enum DiagnosticAxisKey: Hashable {
    case attribute(String)
    case cluster(Int)

    var description: String {
      switch self {
      case let .attribute(name):
        return "attribute:\(name)"
      case let .cluster(clusterID):
        return "cluster:\(clusterID)"
      }
    }
  }

  private enum DiagnosticSideSource: String {
    case attribute
    case cluster
  }

  private static func conflictSimilarity(
    between lhs: DecisionAnalysis,
    and rhs: DecisionAnalysis
  ) -> Double? {
    guard
      let lhsVector = normalizedConflictVector(for: lhs),
      let rhsVector = normalizedConflictVector(for: rhs)
    else {
      return nil
    }
    return dot(lhsVector, rhsVector)
  }

  private static func normalizedConflictVector(for analysis: DecisionAnalysis) -> [Int: Double]? {
    let option1 = clusterScores(for: analysis, optionIndex: 1)
    let option2 = clusterScores(for: analysis, optionIndex: 2)
    let clusterIDs = Set(option1.keys).union(option2.keys)
    let pairs: [(Int, Double)] = clusterIDs.compactMap { clusterID in
      let value = abs((option1[clusterID] ?? 0) - (option2[clusterID] ?? 0))
      guard value > 0.000_000_001 else { return nil }
      return (clusterID, value)
    }
    return normalized(Dictionary(uniqueKeysWithValues: pairs))
  }

  private static func normalizedSignedAxis(
    for analysis: DecisionAnalysis,
    source: DiagnosticSideSource
  ) -> [DiagnosticAxisKey: Double]? {
    switch source {
    case .attribute:
      return signedAttributeAxis(for: analysis)
    case .cluster:
      return signedClusterAxis(for: analysis)
    }
  }

  private static func signedAttributeAxis(for analysis: DecisionAnalysis) -> [DiagnosticAxisKey: Double]? {
    let pairs: [(DiagnosticAxisKey, Double)] = analysis.attributeConflicts.compactMap { conflict in
      let value = conflict.option1Score - conflict.option2Score
      guard abs(value) > 0.000_000_001 else { return nil }
      return (.attribute(conflict.attributeName), value)
    }
    return normalized(Dictionary(pairs, uniquingKeysWith: { first, _ in first }))
  }

  private static func signedClusterAxis(for analysis: DecisionAnalysis) -> [DiagnosticAxisKey: Double]? {
    let option1 = clusterScores(for: analysis, optionIndex: 1)
    let option2 = clusterScores(for: analysis, optionIndex: 2)
    let clusterIDs = Set(option1.keys).union(option2.keys)
    let pairs: [(DiagnosticAxisKey, Double)] = clusterIDs.compactMap { clusterID in
      let value = (option1[clusterID] ?? 0) - (option2[clusterID] ?? 0)
      guard abs(value) > 0.000_000_001 else { return nil }
      return (.cluster(clusterID), value)
    }
    return normalized(Dictionary(uniqueKeysWithValues: pairs))
  }

  private static func clusterScores(for analysis: DecisionAnalysis, optionIndex: Int) -> [Int: Double] {
    let pairs: [(Int, Double)] = analysis.clusterProfiles
      .filter { $0.optionIndex == optionIndex && abs($0.score) > 0.000_000_001 }
      .map { ($0.clusterID, $0.score) }
    return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
  }

  private static func normalized<Key: Hashable>(_ vector: [Key: Double]) -> [Key: Double]? {
    let magnitude = sqrt(vector.values.reduce(0) { $0 + ($1 * $1) })
    guard magnitude > 0.000_000_001 else { return nil }
    return vector.mapValues { $0 / magnitude }
  }

  private static func negated<Key: Hashable>(_ vector: [Key: Double]) -> [Key: Double] {
    vector.mapValues { -$0 }
  }

  private static func dot<Key: Hashable>(_ lhs: [Key: Double], _ rhs: [Key: Double]) -> Double {
    lhs.reduce(0) { total, pair in
      total + (pair.value * (rhs[pair.key] ?? 0))
    }
  }
}

private struct RecommendationRegressionFixture: Decodable {
  let dilemmas: [RecommendationRegressionDilemma]
}

private struct RecommendationRegressionDilemma: Decodable {
  let id: String
  let draft: DilemmaDraftJSON

  private enum CodingKeys: String, CodingKey {
    case id
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    draft = try DilemmaDraftJSON(from: decoder)
  }
}

private extension DilemmaDraftJSON {
  func makeDecisionDraft() throws -> DecisionDraft {
    let draft = try validated()
    return DecisionDraft(
      rawText: draft.rawText,
      options: draft.options.enumerated().map { offset, option in
        DecisionOption(
          index: offset + 1,
          title: option.title,
          reasons: option.benefits.map { Reason(text: $0, polarity: .benefit) }
            + option.costs.map { Reason(text: $0, polarity: .cost) }
        )
      }
    )
  }
}
