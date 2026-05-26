import DecisionModels
import SwiftUI

struct AnalysisDetailView: View {
  @Bindable var model: AnalysisDetailModel

  var body: some View {
    List {
      Section("Dilemma") {
        Text(model.entry.rawText)
      }

      ForEach(model.entry.options) { option in
        Section(option.title) {
          ForEach(option.reasons) { reason in
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: reason.polarity == .benefit ? "plus.circle" : "minus.circle")
                .foregroundStyle(reason.polarity == .benefit ? .green : .red)
              Text(reason.text)
            }
          }
        }
      }

      if let analysis = model.analysis {
        Section("Likely Attribute Conflict") {
          ForEach(analysis.attributeConflicts.prefix(8)) { conflict in
            VStack(alignment: .leading, spacing: 4) {
              Text(conflict.attributeName)
              HStack {
                Text("O1 \(format(conflict.option1Score))")
                Text("O2 \(format(conflict.option2Score))")
                Text("Δ \(format(conflict.difference))")
              }
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
            }
          }
        }

        Section("Top Clusters") {
          ForEach(model.entry.options) { option in
            let clusters = analysis.clusterProfiles
              .filter { $0.optionIndex == option.index }
              .sorted { abs($0.score) > abs($1.score) }
              .prefix(5)

            VStack(alignment: .leading, spacing: 8) {
              Text(option.title)
                .font(.subheadline.weight(.semibold))
              ForEach(Array(clusters)) { cluster in
                HStack {
                  Text(cluster.label)
                    .lineLimit(2)
                  Spacer()
                  Text(format(cluster.score))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
        }

        feedbackSection()
      } else {
        Section("Analysis") {
          Text("No saved analysis is available for this entry.")
            .foregroundStyle(.secondary)
        }
      }

      if let errorMessage = model.errorMessage {
        Section {
          Text(errorMessage)
            .foregroundStyle(.red)
        }
      }
    }
    .navigationTitle("Analysis")
  }

  private func feedbackSection() -> some View {
    Section("Feedback") {
      Toggle("Conflict was useful", isOn: $model.conflictWasUseful)

      Picker("Corrected cluster", selection: $model.correctedClusterID) {
        Text("None").tag(Int?.none)
        ForEach(model.uniqueClusters(), id: \.clusterID) { cluster in
          Text(cluster.label).tag(Optional(cluster.clusterID))
        }
      }

      TextField("Corrected attribute", text: $model.correctedAttributeName)
        .textInputAutocapitalization(.sentences)

      Picker("Recorded choice", selection: $model.chosenOptionIndex) {
        Text("None").tag(Int?.none)
        ForEach(model.entry.options) { option in
          Text(option.title).tag(Optional(option.index))
        }
      }

      TextField("Note", text: $model.note, axis: .vertical)
        .lineLimit(1...4)

      Button {
        model.saveFeedback()
      } label: {
        Label("Save feedback", systemImage: "checkmark.circle")
      }
      .accessibilityIdentifier("save-feedback-button")

      if model.didSaveFeedback {
        Text("Feedback saved locally.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func format(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(3)))
  }
}
