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
        /*
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
        */

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

        chosenClusterSection()
        similarDilemmasSection()
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

      exportSection()
    }
    .navigationTitle("Analysis")
    .task {
      model.reloadPreferenceStatistics()
    }
  }

  private func exportSection() -> some View {
    Section("Export") {
      Button {
        model.prepareExportFile()
      } label: {
        Label("Prepare JSON export", systemImage: "square.and.arrow.up")
      }
      .accessibilityIdentifier("prepare-entry-export-button")

      if let exportURL = model.exportURL {
        ShareLink(item: exportURL) {
          Label("Share JSON", systemImage: "doc")
        }
        .accessibilityIdentifier("share-entry-export-button")
      }
    }
  }

  private func chosenClusterSection() -> some View {
    Section("Chosen Cluster") {
      ChosenClusterCircle(
        topCluster: model.topChosenCluster,
        dilemmaCount: model.chosenClusterDilemmaCount
      )
    }
  }

  private func feedbackSection() -> some View {
    Section("Decision Feedback") {
      Picker("Decision made", selection: $model.chosenOptionIndex) {
        Text("Not decided yet").tag(Int?.none)
        ForEach(model.entry.options) { option in
          Text(option.title).tag(Optional(option.index))
        }
      }
      .pickerStyle(.inline)

      TextField("Note", text: $model.note, axis: .vertical)
        .lineLimit(1...4)

      Button {
        model.saveFeedback()
      } label: {
        Label("Save decision", systemImage: "checkmark.circle")
      }
      .disabled(!model.canSaveFeedback)
      .accessibilityIdentifier("save-feedback-button")

      if model.didSaveFeedback {
        Text("Decision feedback saved locally.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func similarDilemmasSection() -> some View {
    Section("Similar Conflict Clusters") {
      let matches = model.similarDilemmas()
      if matches.isEmpty {
        Text("Similar dilemmas appear after more analyzed entries are saved.")
          .foregroundStyle(.secondary)
      } else {
        ForEach(matches) { match in
          NavigationLink {
            AnalysisDetailView(model: model.makeSimilarDilemmaModel(for: match))
          } label: {
            SimilarDilemmaRow(match: match)
          }
        }
      }
    }
  }

  private func format(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(3)))
  }
}

private struct ChosenClusterCircle: View {
  let topCluster: ClusterFrequency?
  let dilemmaCount: Int

  private var hasData: Bool {
    topCluster != nil && dilemmaCount > 0
  }

  private var progress: Double {
    guard let topCluster, dilemmaCount > 0 else { return 0 }
    return Double(topCluster.count) / Double(dilemmaCount)
  }

  var body: some View {
    HStack(spacing: 18) {
      ZStack {
        Circle()
          .fill(hasData ? Color.teal.opacity(0.08) : Color.gray.opacity(0.12))

        Circle()
          .stroke(hasData ? Color.secondary.opacity(0.14) : Color.gray.opacity(0.35), lineWidth: 14)

        if hasData {
          Circle()
            .trim(from: 0, to: progress)
            .stroke(
              AngularGradient(
                colors: [.teal, .indigo, .mint],
                center: .center
              ),
              style: StrokeStyle(lineWidth: 14, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
        }

        VStack(spacing: 2) {
          Text(hasData ? progress.formatted(.percent.precision(.fractionLength(0))) : "0")
            .font(.title2.monospacedDigit().weight(.bold))
          Text(hasData ? "top" : "cases")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: 118, height: 118)
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 6) {
        Text(topCluster?.label ?? "No chosen cluster yet")
          .font(.headline)
          .lineLimit(3)

        Text("Dilemmas in analysis: \(dilemmaCount)")
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)

        if let topCluster {
          Text("\(topCluster.count) chose this cluster")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 8)
  }
}

private struct SimilarDilemmaRow: View {
  let match: SimilarDilemma

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(match.entry.rawText)
          .font(.subheadline.weight(.semibold))
          .lineLimit(2)
        Spacer()
        Text(match.score.formatted(.percent.precision(.fractionLength(0))))
          .font(.caption.monospacedDigit().weight(.semibold))
          .foregroundStyle(.secondary)
      }

      Text(match.entry.options.map(\.title).joined(separator: " / "))
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)

      if !match.sharedClusterLabels.isEmpty {
        Text(match.sharedClusterLabels.joined(separator: " • "))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 3)
  }
}
