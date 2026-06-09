import Foundation
import Testing

@testable import DecisionKernel
@testable import DecisionModels

@Suite
struct DecisionRecommendationServiceTests {
  private let service = DecisionRecommendationService()

  @Test
  func likelyChoiceAdviceWeightsSideBasedDecidedChoices() throws {
    let currentAnalysis = sampleSideAnalysis(axisScores: [(1, 1), (2, -1)])
    let strongOption1Choice = sampleSideAnalysis(axisScores: [(1, 1), (2, -1)])
    let weakerOption2Choice = sampleSideAnalysis(axisScores: [(1, 1), (2, -0.2)])

    let advice = try #require(service.likelyChoiceAdvice(
      currentAnalysis: currentAnalysis,
      currentOptionIndices: [1, 2],
      decidedChoices: [
        SimilarDecidedChoice(analysis: strongOption1Choice, chosenOptionIndex: 1),
        SimilarDecidedChoice(analysis: weakerOption2Choice, chosenOptionIndex: 2),
      ]
    ))

    #expect(advice.optionIndex == 1)
    #expect(advice.decidedDilemmaCount == 2)
    #expect((advice.optionWeights[1] ?? 0) > (advice.optionWeights[2] ?? 0))
    #expect(advice.support > 0.5)
    #expect(advice.support < 1)
  }

  @Test
  func likelyChoiceAdviceShowsUniqueLeaderBelowOldSupportThreshold() throws {
    let currentAnalysis = sampleSideAnalysis(axisScores: [(1, 1)])
    let option1Choice = sampleSideAnalysis(axisScores: [(1, 1)])
    let nearOption2Choice = sampleSideAnalysis(axisScores: [(1, 1), (2, 0.2)])

    let advice = try #require(service.likelyChoiceAdvice(
      currentAnalysis: currentAnalysis,
      currentOptionIndices: [1, 2],
      decidedChoices: [
        SimilarDecidedChoice(analysis: option1Choice, chosenOptionIndex: 1),
        SimilarDecidedChoice(analysis: nearOption2Choice, chosenOptionIndex: 2),
      ]
    ))

    #expect(advice.optionIndex == 1)
    #expect(advice.support > 0.5)
    #expect(advice.support < 0.55)
  }

  @Test
  func likelyChoiceAdviceAllowsOneSimilarDecidedChoice() throws {
    let currentAnalysis = sampleSideAnalysis(axisScores: [(1, 1), (2, -1)])
    let pastAnalysis = sampleSideAnalysis(axisScores: [(1, 1), (2, -1)])

    let advice = try #require(service.likelyChoiceAdvice(
      currentAnalysis: currentAnalysis,
      currentOptionIndices: [1, 2],
      decidedChoices: [
        SimilarDecidedChoice(analysis: pastAnalysis, chosenOptionIndex: 2),
      ]
    ))

    #expect(advice.optionIndex == 2)
    #expect(advice.decidedDilemmaCount == 1)
    #expect(abs(advice.support - 1) < 0.0001)
  }

  @Test
  func likelyChoiceAdviceMapsPastChoiceBySideNotOptionNumber() throws {
    let currentAnalysis = sampleSideAnalysis(axisScores: [(1, 1), (2, -1)])
    let pastAnalysis = sampleSideAnalysis(axisScores: [(1, -1), (2, 1)])

    let advice = try #require(service.likelyChoiceAdvice(
      currentAnalysis: currentAnalysis,
      currentOptionIndices: [1, 2],
      decidedChoices: [
        SimilarDecidedChoice(analysis: pastAnalysis, chosenOptionIndex: 1),
      ]
    ))

    #expect(advice.optionIndex == 2)
  }

  @Test
  func likelyChoiceAdviceReturnsAmbiguousAdviceForTie() throws {
    let currentAnalysis = sampleSideAnalysis(axisScores: [(1, 1), (2, -1)])
    let option1Choice = sampleSideAnalysis(axisScores: [(1, 1), (2, -1)])
    let option2Choice = sampleSideAnalysis(axisScores: [(1, 1), (2, -1)])

    let advice = try #require(service.likelyChoiceAdvice(
      currentAnalysis: currentAnalysis,
      currentOptionIndices: [1, 2],
      decidedChoices: [
        SimilarDecidedChoice(analysis: option1Choice, chosenOptionIndex: 1),
        SimilarDecidedChoice(analysis: option2Choice, chosenOptionIndex: 2),
      ]
    ))

    #expect(advice.optionIndex == nil)
    #expect(advice.decidedDilemmaCount == 2)
    #expect(abs(advice.support - 0.5) < 0.0001)
    #expect(abs((advice.supportByOption[1] ?? 0) - 0.5) < 0.0001)
    #expect(abs((advice.supportByOption[2] ?? 0) - 0.5) < 0.0001)
  }

  @Test
  func likelyChoiceAdviceReturnsNilForNoSupport() {
    let currentAnalysis = sampleSideAnalysis(axisScores: [(1, 1), (2, 0)])
    let noisyChoice = sampleSideAnalysis(
      axisScores: [(1, 0.02), (2, 1)]
    )

    let unsupportedAdvice = service.likelyChoiceAdvice(
      currentAnalysis: currentAnalysis,
      currentOptionIndices: [1, 2],
      decidedChoices: [
        SimilarDecidedChoice(analysis: noisyChoice, chosenOptionIndex: 1),
      ]
    )

    #expect(unsupportedAdvice == nil)
  }

  @Test
  func likelyChoiceAdviceMapsQualitySpeedSidesForSocks() throws {
    let socksAnalysis = sampleSideAnalysis(axisScores: [(1, 1), (2, -1)])
    let bikeRepairAnalysis = sampleSideAnalysis(axisScores: [(1, 1), (2, -1)])
    let workReportAnalysis = sampleSideAnalysis(axisScores: [(1, 1), (2, -1)])

    let speedAdvice = try #require(service.likelyChoiceAdvice(
      currentAnalysis: socksAnalysis,
      currentOptionIndices: [1, 2],
      decidedChoices: [
        SimilarDecidedChoice(analysis: bikeRepairAnalysis, chosenOptionIndex: 2),
      ]
    ))
    let qualityAdvice = try #require(service.likelyChoiceAdvice(
      currentAnalysis: socksAnalysis,
      currentOptionIndices: [1, 2],
      decidedChoices: [
        SimilarDecidedChoice(analysis: workReportAnalysis, chosenOptionIndex: 1),
      ]
    ))
    let combinedAdvice = try #require(service.likelyChoiceAdvice(
      currentAnalysis: socksAnalysis,
      currentOptionIndices: [1, 2],
      decidedChoices: [
        SimilarDecidedChoice(analysis: bikeRepairAnalysis, chosenOptionIndex: 2),
        SimilarDecidedChoice(analysis: workReportAnalysis, chosenOptionIndex: 1),
      ]
    ))

    #expect(speedAdvice.optionIndex == 2)
    #expect(qualityAdvice.optionIndex == 1)
    #expect(combinedAdvice.optionIndex == nil)
    #expect(combinedAdvice.decidedDilemmaCount == 2)
    #expect(abs(combinedAdvice.support - 0.5) < 0.0001)
    #expect(abs((combinedAdvice.supportByOption[1] ?? 0) - 0.5) < 0.0001)
    #expect(abs((combinedAdvice.supportByOption[2] ?? 0) - 0.5) < 0.0001)
  }

  @Test
  func likelyChoiceAdviceUsesFullAttributeProfilesBeyondTopConflictProjection() throws {
    let currentAnalysis = sampleFullAttributeSideAnalysis(
      axisScores: (1...8).map { ($0, 1.0) } + [(9, 0.1)]
    )
    let pastAnalysis = sampleFullAttributeSideAnalysis(
      axisScores: (1...8).map { ($0, 0.0) } + [(9, 0.1)]
    )

    #expect(currentAnalysis.attributeConflicts.allSatisfy { $0.attributeName != "Axis 9" })

    let advice = try #require(service.likelyChoiceAdvice(
      currentAnalysis: currentAnalysis,
      currentOptionIndices: [1, 2],
      decidedChoices: [
        SimilarDecidedChoice(analysis: pastAnalysis, chosenOptionIndex: 1),
      ]
    ))

    #expect(advice.optionIndex == 1)
    #expect((advice.optionWeights[1] ?? 0) > 0)
    #expect((advice.optionWeights[2] ?? 0) == 0)
  }

  private func sampleAnalysis(
    entryID: UUID,
    attributeConflicts: [AttributeConflict] = [],
    clusterProfiles: [ClusterProfile]
  ) -> DecisionAnalysis {
    DecisionAnalysis(
      entryID: entryID,
      assetVersion: 1,
      modelID: "stub-model",
      sourceDOI: "stub-doi",
      attributeConflicts: attributeConflicts,
      clusterProfiles: clusterProfiles
    )
  }

  private func sampleSideAnalysis(axisScores: [(Int, Double)]) -> DecisionAnalysis {
    sampleAnalysis(
      entryID: UUID(),
      attributeConflicts: attributeConflicts(axisScores: axisScores),
      clusterProfiles: clusterProfiles(
        optionIndex: 1,
        scores: axisScores.map { ($0.0, $0.1 / 2) }
      )
        + clusterProfiles(
          optionIndex: 2,
          scores: axisScores.map { ($0.0, -$0.1 / 2) }
        )
    )
  }

  private func sampleFullAttributeSideAnalysis(axisScores: [(Int, Double)]) -> DecisionAnalysis {
    let embedding = EmbeddingVector(
      modelID: "stub-model",
      modelName: "Stub model",
      dimension: 2,
      values: [1, 0]
    )

    return DecisionAnalysis(
      entryID: UUID(),
      model: AnalysisModelMetadata(id: "stub-model", name: "Stub model", embeddingDimension: 2),
      asset: AnalysisAssetMetadata(version: 1, resourceName: "stub-asset", sourceDOI: "stub-doi"),
      clusterMethod: AnalysisClusterMethodMetadata(id: "stub-cluster", label: "Stub cluster"),
      embeddings: DecisionAnalysisEmbeddings(
        rawText: "Stub dilemma",
        dilemmaText: embedding,
        options: [
          OptionEmbedding(optionIndex: 1, title: "Option 1", embedding: embedding),
          OptionEmbedding(optionIndex: 2, title: "Option 2", embedding: embedding),
        ],
        reasons: [
          ReasonEmbedding(
            reasonID: UUID(),
            optionIndex: 1,
            polarity: .benefit,
            text: "Reason",
            embedding: embedding
          ),
        ]
      ),
      reasonMatches: [],
      optionAttributeProfiles: [
        OptionAttributeProfile(
          optionIndex: 1,
          scores: attributeProfileScores(axisScores: axisScores, multiplier: 0.5)
        ),
        OptionAttributeProfile(
          optionIndex: 2,
          scores: attributeProfileScores(axisScores: axisScores, multiplier: -0.5)
        ),
      ],
      optionClusterProfiles: [
        OptionClusterProfile(
          optionIndex: 1,
          scores: [ClusterScore(cluster: sampleClusterMetadata(id: 1), score: 0.5)]
        ),
        OptionClusterProfile(
          optionIndex: 2,
          scores: [ClusterScore(cluster: sampleClusterMetadata(id: 1), score: -0.5)]
        ),
      ],
      metrics: AnalysisMetrics(),
      warnings: []
    )
  }

  private func attributeProfileScores(
    axisScores: [(Int, Double)],
    multiplier: Double
  ) -> [AttributeProfileScore] {
    axisScores.map { attributeID, score in
      AttributeProfileScore(
        attribute: AttributeDefinition(
          attributeID: attributeID,
          name: "Axis \(attributeID)",
          source: "stub",
          clusterID: nil
        ),
        score: Float(score * multiplier)
      )
    }
  }

  private func attributeConflicts(axisScores: [(Int, Double)]) -> [AttributeConflict] {
    axisScores.enumerated().map { offset, pair in
      AttributeConflict(
        attributeName: "Axis \(pair.0)",
        option1Score: pair.1 / 2,
        option2Score: -pair.1 / 2,
        difference: abs(pair.1),
        rank: offset + 1
      )
    }
  }

  private func clusterProfiles(
    optionIndex: Int,
    scores: [(Int, Double)]
  ) -> [ClusterProfile] {
    scores.map { clusterID, score in
      ClusterProfile(
        optionIndex: optionIndex,
        clusterID: clusterID,
        label: "Cluster \(clusterID)",
        score: score
      )
    }
  }

  private func sampleClusterMetadata(id: Int) -> ClusterMetadata {
    ClusterMetadata(
      clusterID: id,
      label: "Cluster \(id)",
      representativeAttributeName: "Axis \(id)",
      sortOrder: id
    )
  }
}
