import DecisionKernel
import DecisionModels

/// Internal adapter around `DecisionKernel`.
/// It keeps kernel execution behind a use case boundary so app workflows receive only `DecisionAnalysis`.
struct RunDecisionAnalysisUseCase: Sendable {
  private let service: DecisionAnalysisService

  init(service: DecisionAnalysisService = DecisionAnalysisService()) {
    self.service = service
  }

  func callAsFunction(_ draft: DecisionDraft) async throws -> DecisionAnalysis {
    try await service.analyze(draft)
  }

  func callAsFunction() async throws -> DecisionAnalysis {
    try await DecisionAnalysisRunner().run()
  }
}
