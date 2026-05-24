import DecisionKernel
import Foundation

struct RunDecisionAnalysisUseCase: Sendable {
  private let runner: DecisionAnalysisRunner

  init(runner: DecisionAnalysisRunner = DecisionAnalysisRunner()) {
    self.runner = runner
  }

  func callAsFunction() async throws -> DecisionAnalysisResult {
    try await runner.run()
  }
}
