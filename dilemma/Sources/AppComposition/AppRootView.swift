import SwiftUI

struct AppRootView: View {
  private let runAnalysis = RunDecisionAnalysisUseCase()

  var body: some View {
    AnalysisDebugView(runAnalysis: runAnalysis)
  }
}
