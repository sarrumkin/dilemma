import Foundation
import Testing

@testable import DecisionKernel

@Suite
struct DecisionAnalysisRunnerIntegrationTests {
  @Test(
    .enabled(
      if: DecisionKernelResources.bundle.url(
        forResource: "all-MiniLM-L6-v2",
        withExtension: nil,
        subdirectory: "Models"
      ) != nil,
      "Bundled L6 model folder is not present in the kernel bundle."
    )
  )
  func bundledL6RunnerProducesMappings() async throws {
    let result = try await DecisionAnalysisRunner(
      modelResourceName: "all-MiniLM-L6-v2",
      attributesResourceName: "attributes_l6"
    ).run()

    #expect(result.reasonResults.count == 12)
    #expect(!result.conflictDimensions.isEmpty)
    #expect(result.metrics.modelLoadMilliseconds > 0)
    #expect(result.metrics.embeddingMilliseconds > 0)
    #expect(result.metrics.scoringMilliseconds < 100)

    print("ANALYSIS_L6_MODEL_LOAD_MS=\(result.metrics.modelLoadMilliseconds)")
    print("ANALYSIS_L6_EMBED_12_MS=\(result.metrics.embeddingMilliseconds)")
    print("ANALYSIS_L6_SCORE_MS=\(result.metrics.scoringMilliseconds)")
    print("ANALYSIS_L6_MEMORY_MB=\(result.metrics.approximateMemoryMegabytes)")
    if let first = result.reasonResults.first {
      print("ANALYSIS_L6_FIRST_REASON_TOP5=\(first.topMatches.map { $0.attribute.name })")
    }
  }

  @Test(
    .enabled(
      if: DecisionKernelResources.bundle.url(
        forResource: "all-MiniLM-L12-v2",
        withExtension: nil,
        subdirectory: "Models"
      ) != nil,
      "Bundled L12 model folder is not present in the kernel bundle."
    )
  )
  func bundledL12RunnerProducesMappings() async throws {
    let result = try await DecisionAnalysisRunner(
      modelResourceName: "all-MiniLM-L12-v2",
      attributesResourceName: "attributes_l12"
    ).run()

    #expect(result.reasonResults.count == 12)
    #expect(!result.conflictDimensions.isEmpty)
    #expect(result.metrics.modelLoadMilliseconds > 0)
    #expect(result.metrics.embeddingMilliseconds > 0)
    #expect(result.metrics.scoringMilliseconds < 100)

    print("ANALYSIS_L12_MODEL_LOAD_MS=\(result.metrics.modelLoadMilliseconds)")
    print("ANALYSIS_L12_EMBED_12_MS=\(result.metrics.embeddingMilliseconds)")
    print("ANALYSIS_L12_SCORE_MS=\(result.metrics.scoringMilliseconds)")
    print("ANALYSIS_L12_MEMORY_MB=\(result.metrics.approximateMemoryMegabytes)")
    if let first = result.reasonResults.first {
      print("ANALYSIS_L12_FIRST_REASON_TOP5=\(first.topMatches.map { $0.attribute.name })")
    }
  }
}
