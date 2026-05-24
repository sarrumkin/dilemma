import DiaryVault
import SwiftUI

struct AnalysisDetailView: View {
  @EnvironmentObject private var model: DilemmaAppModel
  let entry: DiaryEntryRecord
  let analysis: StoredDecisionAnalysis?

  @State private var conflictWasUseful = true
  @State private var correctedClusterID: Int?
  @State private var correctedAttributeName = ""
  @State private var chosenOptionIndex: Int?
  @State private var note = ""
  @State private var didSaveFeedback = false

  var body: some View {
    List {
      Section("Dilemma") {
        Text(entry.rawText)
      }

      ForEach(entry.options) { option in
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

      if let analysis {
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
          ForEach(entry.options) { option in
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

        feedbackSection(analysis: analysis)
      } else {
        Section("Analysis") {
          Text("No saved analysis is available for this entry.")
            .foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle("Analysis")
  }

  private func feedbackSection(analysis: StoredDecisionAnalysis) -> some View {
    Section("Feedback") {
      Toggle("Conflict was useful", isOn: $conflictWasUseful)

      Picker("Corrected cluster", selection: $correctedClusterID) {
        Text("None").tag(Int?.none)
        ForEach(uniqueClusters(in: analysis), id: \.clusterID) { cluster in
          Text(cluster.label).tag(Optional(cluster.clusterID))
        }
      }

      TextField("Corrected attribute", text: $correctedAttributeName)
        .textInputAutocapitalization(.sentences)

      Picker("Recorded choice", selection: $chosenOptionIndex) {
        Text("None").tag(Int?.none)
        ForEach(entry.options) { option in
          Text(option.title).tag(Optional(option.index))
        }
      }

      TextField("Note", text: $note, axis: .vertical)
        .lineLimit(1...4)

      Button {
        model.saveFeedback(
          entry: entry,
          analysis: analysis,
          conflictWasUseful: conflictWasUseful,
          correctedClusterID: correctedClusterID,
          correctedAttributeName: correctedAttributeName,
          chosenOptionIndex: chosenOptionIndex,
          note: note
        )
        didSaveFeedback = true
      } label: {
        Label("Save feedback", systemImage: "checkmark.circle")
      }
      .accessibilityIdentifier("save-feedback-button")

      if didSaveFeedback {
        Text("Feedback saved locally.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func uniqueClusters(in analysis: StoredDecisionAnalysis) -> [StoredClusterProfile] {
    Dictionary(grouping: analysis.clusterProfiles, by: \.clusterID)
      .compactMap { $0.value.first }
      .sorted { $0.clusterID < $1.clusterID }
  }

  private func format(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(3)))
  }
}
