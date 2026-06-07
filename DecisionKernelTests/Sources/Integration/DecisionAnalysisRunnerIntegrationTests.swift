import Foundation
import Testing
import DecisionModels

@testable import DecisionKernel

/// Интеграционные проверки DecisionAnalysisRunner на bundled model и SQLite assets.
@Suite
struct DecisionAnalysisRunnerIntegrationTests {
  private static let multilingualModelID = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
  private static let multilingualModelResourceName = "paraphrase-multilingual-MiniLM-L12-v2"

  private static var multilingualModelAvailable: Bool {
    DecisionKernelResourceBundle.bundle.url(
      forResource: multilingualModelResourceName,
      withExtension: nil,
      subdirectory: "Models"
    ) != nil
  }

  /// Проверяет production runner с Bhatia Ward asset и печатает базовые runtime-метрики.
  @Test(
    .enabled(
      if: Self.multilingualModelAvailable,
      "Bundled multilingual MiniLM model folder is not present in the kernel bundle."
    )
  )
  func bundledProductionRunnerProducesMappings() async throws {
    let result = try await DecisionAnalysisRunner().run()

    #expect(result.reasonResults.count == 12)
    #expect(!result.conflictDimensions.isEmpty)
    #expect(!result.clusterConflictDimensions.isEmpty)
    #expect(result.optionProfiles[1]?.count == 207)
    #expect(result.clusterProfilesByOption[1]?.count == 25)
    #expect(result.assetVersion == 2)
    #expect(result.modelName == Self.multilingualModelID)
    #expect(result.assetResourceName == DecisionClusterMethod.bhatiaWardReddit.assetResourceName)
    #expect(result.clusterMethodID == DecisionClusterMethod.bhatiaWardReddit.rawValue)
    #expect(result.metrics.modelLoadMilliseconds > 0)
    #expect(result.metrics.embeddingMilliseconds > 0)
    #expect(result.metrics.scoringMilliseconds < 100)

    print("ANALYSIS_PRODUCTION_MODEL_LOAD_MS=\(result.metrics.modelLoadMilliseconds)")
    print("ANALYSIS_PRODUCTION_EMBED_12_MS=\(result.metrics.embeddingMilliseconds)")
    print("ANALYSIS_PRODUCTION_SCORE_MS=\(result.metrics.scoringMilliseconds)")
    print("ANALYSIS_PRODUCTION_MEMORY_MB=\(result.metrics.approximateMemoryMegabytes)")
    if let first = result.reasonResults.first {
      print("ANALYSIS_PRODUCTION_FIRST_REASON_TOP5=\(first.topMatches.map { $0.attribute.name })")
    }
  }

  /// Проверяет альтернативный KMeans asset через тот же DecisionAnalysisRunner API.
  @Test(
    .enabled(
      if: Self.multilingualModelAvailable
        && DecisionKernelResourceBundle.bundle.url(
          forResource: "DilemmaAssetsKMeans",
          withExtension: "sqlite",
          subdirectory: "Attributes"
        ) != nil,
      "Bundled multilingual MiniLM model folder or KMeans SQLite asset is not present."
    )
  )
  func bundledKMeansRunnerProducesMappings() async throws {
    let result = try await DecisionAnalysisRunner(
      clusterMethod: .kMeansAttributeEmbeddings
    ).run()

    #expect(result.reasonResults.count == 12)
    #expect(result.optionProfiles[1]?.count == 207)
    #expect(result.clusterProfilesByOption[1]?.count == 25)
    #expect(result.assetVersion == 2)
    #expect(result.modelName == Self.multilingualModelID)
    #expect(result.assetResourceName == DecisionClusterMethod.kMeansAttributeEmbeddings.assetResourceName)
    #expect(result.clusterMethodID == DecisionClusterMethod.kMeansAttributeEmbeddings.rawValue)
  }

  /// Проверяет, что русский structured draft анализируется локальной multilingual model.
  @Test(
    .enabled(
      if: Self.multilingualModelAvailable,
      "Bundled multilingual MiniLM model folder is not present in the kernel bundle."
    )
  )
  func russianDraftProducesMultilingualAnalysis() async throws {
    let result = try await DecisionAnalysisService().analyze(Self.russianDraft)

    #expect(result.reasonResults.count == 12)
    #expect(!result.conflictDimensions.isEmpty)
    #expect(!result.clusterConflictDimensions.isEmpty)
    #expect(result.optionProfiles[1]?.count == 207)
    #expect(result.clusterProfilesByOption[1]?.count == 25)
    #expect(result.assetVersion == 2)
    #expect(result.modelName == Self.multilingualModelID)
    #expect(result.assetResourceName == DecisionClusterMethod.bhatiaWardReddit.assetResourceName)
  }

  private static let russianDraft = DecisionDraft(
    rawText: "Стоит ли мне остаться на стабильной работе или переехать ради новой возможности?",
    options: [
      DecisionOption(
        index: 1,
        title: "Остаться на стабильной работе",
        reasons: [
          Reason(text: "У меня останется стабильный доход.", polarity: .benefit),
          Reason(text: "У меня будет больше времени с семьей.", polarity: .benefit),
          Reason(text: "Так будет безопаснее в долгосрочной перспективе.", polarity: .benefit),
          Reason(text: "Это может ограничить карьерный рост.", polarity: .cost),
          Reason(text: "У меня будет меньше независимости.", polarity: .cost),
          Reason(text: "Мне может стать скучно.", polarity: .cost),
        ]
      ),
      DecisionOption(
        index: 2,
        title: "Переехать ради новой возможности",
        reasons: [
          Reason(text: "Это может улучшить мои карьерные перспективы.", polarity: .benefit),
          Reason(text: "У меня будет больше независимости.", polarity: .benefit),
          Reason(text: "Я смогу освоить новые полезные навыки.", polarity: .benefit),
          Reason(text: "Есть финансовый риск.", polarity: .cost),
          Reason(text: "Это может навредить моему психическому здоровью.", polarity: .cost),
          Reason(text: "Это потребует много времени и усилий.", polarity: .cost),
        ]
      ),
    ]
  )
}
