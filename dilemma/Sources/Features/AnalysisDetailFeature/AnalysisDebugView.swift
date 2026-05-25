import DecisionKernel
import DecisionUseCases
import SwiftUI

struct AnalysisDebugView: View {
  let runAnalysis: RunDecisionAnalysisUseCase

  @State private var isRunning = false
  @State private var result: DecisionAnalysisResult?
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Button {
            runMapping()
          } label: {
            if isRunning {
              ProgressView()
            } else {
              Text("Run Analysis")
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(isRunning)

          if let errorMessage {
            Text(errorMessage)
              .font(.callout)
              .foregroundStyle(.red)
          }

          if let result {
            // The prototype keeps output raw and inspectable:
            // metrics first, then per-reason matches, then profile deltas.
            ResultView(result: result)
          }
        }
        .padding()
      }
      .navigationTitle("dilemma")
    }
  }

  private func runMapping() {
    isRunning = true
    errorMessage = nil
    result = nil
    let runAnalysis = self.runAnalysis

    Task {
      do {
        let output = try await runAnalysis()
        await MainActor.run {
          result = output
          isRunning = false
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          isRunning = false
        }
      }
    }
  }
}

private struct ResultView: View {
  let result: DecisionAnalysisResult

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      metricsSection
      reasonMatchesSection
      conflictSection
    }
  }

  private var metricsSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(result.modelName).font(.headline)
      Text("Model load: \(format(result.metrics.modelLoadMilliseconds)) ms")
      Text("Embedding 12 reasons: \(format(result.metrics.embeddingMilliseconds)) ms")
      Text("Scoring 12 x 414: \(format(result.metrics.scoringMilliseconds)) ms")
      Text("Approx memory delta: \(format(result.metrics.approximateMemoryMegabytes)) MB")
    }
    .font(.subheadline.monospacedDigit())
  }

  private var reasonMatchesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Top-5 attributes per reason").font(.headline)
      ForEach(result.reasonResults) { reasonResult in
        VStack(alignment: .leading, spacing: 5) {
          Text(reasonResult.reason.text)
            .font(.subheadline.weight(.semibold))
          Text("Option \(reasonResult.reason.optionIndex) / \(reasonResult.reason.polarity.rawValue)")
            .font(.caption)
            .foregroundStyle(.secondary)
          ForEach(reasonResult.topMatches) { match in
            Text("\(match.attribute.name) (\(match.attribute.direction.rawValue)): \(format(match.score))")
              .font(.caption.monospacedDigit())
          }
        }
        .padding(.vertical, 6)
      }
    }
  }

  private var conflictSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Предполагаемый attribute conflict").font(.headline)
      ForEach(result.conflictDimensions) { dimension in
        Text("\(dimension.attributeName): \(format(dimension.difference))")
          .font(.caption.monospacedDigit())
      }
    }
  }

  private func format(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1)))
  }

  private func format(_ value: Float) -> String {
    Double(value).formatted(.number.precision(.fractionLength(3)))
  }
}
