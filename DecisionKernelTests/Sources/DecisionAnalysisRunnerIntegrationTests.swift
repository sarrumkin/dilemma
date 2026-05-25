import Foundation
import Testing

@testable import DecisionKernel

@Suite
struct DecisionAnalysisRunnerIntegrationTests {
  @Test(
    .enabled(
      if: DecisionKernelResourceBundle.bundle.url(
        forResource: "all-MiniLM-L12-v2",
        withExtension: nil,
        subdirectory: "Models"
      ) != nil,
      "Bundled L12 model folder is not present in the kernel bundle."
    )
  )
  func bundledProductionRunnerProducesMappings() async throws {
    let result = try await DecisionAnalysisRunner().run()

    #expect(result.reasonResults.count == 12)
    #expect(!result.conflictDimensions.isEmpty)
    #expect(!result.clusterConflictDimensions.isEmpty)
    #expect(result.optionProfiles[1]?.count == 207)
    #expect(result.clusterProfiles[1]?.count == 25)
    #expect(result.assetVersion == 1)
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
}
