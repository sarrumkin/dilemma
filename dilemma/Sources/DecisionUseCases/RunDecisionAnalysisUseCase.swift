import DecisionKernel
import Foundation

struct RunDecisionAnalysisUseCase: Sendable {
  private let service: DecisionAnalysisService

  init(service: DecisionAnalysisService = DecisionAnalysisService()) {
    self.service = service
  }

  func callAsFunction(_ draft: DecisionDraft) async throws -> DecisionAnalysisResult {
    try await service.analyze(draft)
  }

  func callAsFunction() async throws -> DecisionAnalysisResult {
    try await DecisionAnalysisRunner().run()
  }
}
