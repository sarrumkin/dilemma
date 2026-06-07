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
              Text(TaxonomyLocalization.attributeName(sourceName: conflict.attributeName))
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
            let clusters = topClusters(for: option, in: analysis)

            VStack(alignment: .leading, spacing: 8) {
              Text(option.title)
                .font(.subheadline.weight(.semibold))
              ForEach(clusters) { cluster in
                HStack {
                  Text(TaxonomyLocalization.clusterName(clusterID: cluster.clusterID, fallback: cluster.label))
                    .lineLimit(2)
                  Spacer()
                  Text(format(cluster.score))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(scoreColor(cluster.score))
                }
              }
            }
          }
        }

        likelyChoiceSection()
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
      model.reloadSavedFeedback()
      model.reloadLikelyChoiceAdvice()
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

  private func likelyChoiceSection() -> some View {
    Section("Likely Choice") {
      LikelyChoiceAdvicePanel(
        advice: model.likelyChoiceAdvice,
        optionTitles: model.optionTitlesByIndex
      )
      .accessibilityIdentifier("likely-choice-advice")
    }
  }

  private func feedbackSection() -> some View {
    Section("Decision Feedback") {
      if model.isEditingFeedback {
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
          Label(model.saveFeedbackButtonTitle, systemImage: "checkmark.circle")
        }
        .disabled(!model.canSaveFeedback)
        .accessibilityIdentifier("save-feedback-button")

        Button(role: .cancel) {
          model.cancelEditingFeedback()
        } label: {
          Label("Cancel", systemImage: "xmark.circle")
        }
        .accessibilityIdentifier("cancel-feedback-edit-button")
      } else {
        Text(model.savedDecisionTitle)

        Button {
          model.startEditingFeedback()
        } label: {
          Label("Edit Decision", systemImage: "pencil")
        }
        .accessibilityIdentifier("edit-decision-button")
      }

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

  private func topClusters(for option: DiaryOption, in analysis: DecisionAnalysis) -> [ClusterProfile] {
    let optionClusters = analysis.clusterProfiles
      .filter { $0.optionIndex == option.index && $0.score != 0 }

    let positives = optionClusters
      .filter { $0.score > 0 }
      .sorted { left, right in
        if left.score == right.score {
          return left.clusterID < right.clusterID
        }
        return left.score > right.score
      }
      .prefix(3)

    let negatives = optionClusters
      .filter { $0.score < 0 }
      .sorted { left, right in
        if left.score == right.score {
          return left.clusterID < right.clusterID
        }
        return left.score < right.score
      }
      .prefix(3)

    return Array(positives) + Array(negatives)
  }

  private func scoreColor(_ score: Double) -> Color {
    score > 0 ? .green : .red
  }
}

private struct LikelyChoiceAdvicePanel: View {
  let advice: LikelyChoiceAdvice?
  let optionTitles: [Int: String]

  var body: some View {
    if let advice {
      if let optionIndex = advice.optionIndex {
        decisiveAdvice(advice, optionTitle: optionTitle(for: optionIndex))
      } else {
        ambiguousAdvice(advice)
      }
    } else {
      Text("Save choices in similar dilemmas to see a likely choice here.")
        .foregroundStyle(.secondary)
    }
  }

  private func decisiveAdvice(_ advice: LikelyChoiceAdvice, optionTitle: String) -> some View {
    HStack(spacing: 18) {
      ZStack {
        Circle()
          .fill(Color.teal.opacity(0.08))

        Circle()
          .stroke(Color.secondary.opacity(0.14), lineWidth: 14)

        Circle()
          .trim(from: 0, to: clamped(advice.support))
          .stroke(.teal, style: StrokeStyle(lineWidth: 14, lineCap: .round))
          .rotationEffect(.degrees(-90))

        VStack(spacing: 2) {
          Text(advice.support.formatted(.percent.precision(.fractionLength(0))))
            .font(.title2.monospacedDigit().weight(.bold))
          Text("support")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: 118, height: 118)
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 6) {
        Text(optionTitle)
          .font(.headline)
          .lineLimit(3)

        Text(sourceText(for: advice.decidedDilemmaCount))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 8)
  }

  private func ambiguousAdvice(_ advice: LikelyChoiceAdvice) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("No clear likely choice yet")
          .font(.headline)

        Text(sourceText(for: advice.decidedDilemmaCount))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 10) {
        ForEach(supportRows(for: advice), id: \.optionIndex) { row in
          VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
              Text(row.title)
                .font(.subheadline)
                .lineLimit(2)
              Spacer()
              Text(row.support.formatted(.percent.precision(.fractionLength(0))))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
            }

            ProgressView(value: clamped(row.support))
              .tint(.teal)
          }
        }
      }
    }
    .padding(.vertical, 8)
  }

  private func optionTitle(for optionIndex: Int) -> String {
    optionTitles[optionIndex] ?? "Option \(optionIndex)"
  }

  private func supportRows(for advice: LikelyChoiceAdvice) -> [SupportRow] {
    optionTitles.keys.sorted().map { optionIndex in
      SupportRow(
        optionIndex: optionIndex,
        title: optionTitle(for: optionIndex),
        support: advice.supportByOption[optionIndex] ?? 0
      )
    }
  }

  private func clamped(_ value: Double) -> Double {
    min(max(value, 0), 1)
  }

  private func sourceText(for count: Int) -> String {
    if count == 1 {
      return "Based on 1 similar decided dilemma"
    }
    return "Based on \(count) similar decided dilemmas"
  }

  private struct SupportRow {
    let optionIndex: Int
    let title: String
    let support: Double
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

      if !match.sharedClusters.isEmpty {
        Text(
          match.sharedClusters
            .map { TaxonomyLocalization.clusterName(clusterID: $0.clusterID, fallback: $0.label) }
            .joined(separator: " • ")
        )
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 3)
  }
}
