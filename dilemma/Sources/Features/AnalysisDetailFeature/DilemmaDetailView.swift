import DecisionModels
import DecisionUseCases
import SwiftUI

struct DilemmaDetailView: View {
  @Bindable var model: AnalysisDetailModel
  @State private var isShowingAnalysis = false

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

      if model.analysis != nil {
        likelyHintSection()
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
    .navigationTitle("Dilemma")
    .task {
      model.reloadSavedFeedback()
      model.reloadLikelyChoiceAdvice()
    }
    .sheet(isPresented: $isShowingAnalysis) {
      NavigationStack {
        DilemmaAnalysisView(model: model)
      }
    }
  }

  private func likelyHintSection() -> some View {
    Section("Likely Hint") {
      Button {
        isShowingAnalysis = true
      } label: {
        HStack(alignment: .center, spacing: 12) {
          LikelyChoiceAdvicePanel(
            advice: model.likelyChoiceAdvice,
            status: model.likelyChoiceAdviceStatus,
            optionTitles: model.optionTitlesByIndex,
            recordedChoiceTitle: model.recordedChoiceTitle,
            showsRecordedChoice: true
          )
          .frame(maxWidth: .infinity, alignment: .leading)

          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
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
          Label(model.hasSavedFeedback ? "Save changes" : "Save decision", systemImage: "checkmark.circle")
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
        if let recordedChoiceTitle = model.recordedChoiceTitle {
          Text(recordedChoiceTitle)
        } else {
          Text("Not decided yet")
        }

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
}

struct DilemmaAnalysisView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var model: AnalysisDetailModel

  var body: some View {
    List {
      supportSection()
      similarDilemmasSection()
      attributesSection()
      clustersSection()
    }
    .navigationTitle("Analysis")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Close") {
          dismiss()
        }
      }
    }
    .task {
      model.reloadSavedFeedback()
      model.reloadLikelyChoiceAdvice()
    }
  }

  private func supportSection() -> some View {
    Section("Likely Hint") {
      LikelyChoiceAdvicePanel(
        advice: model.likelyChoiceAdvice,
        status: model.likelyChoiceAdviceStatus,
        optionTitles: model.optionTitlesByIndex,
        recordedChoiceTitle: nil,
        showsRecordedChoice: false
      )
      .accessibilityIdentifier("analysis-likely-choice-advice")
    }
  }

  private func similarDilemmasSection() -> some View {
    SimilarDilemmasSection(matches: model.similarDilemmas()) { match in
      DilemmaDetailView(model: model.makeSimilarDilemmaModel(for: match))
    }
  }

  private func clustersSection() -> some View {
    Section("Clusters") {
      if let analysis = model.analysis {
        DilemmaClustersContent(entry: model.entry, analysis: analysis)
      } else {
        Text("No saved analysis is available for this entry.")
          .foregroundStyle(.secondary)
      }
    }
  }

  private func attributesSection() -> some View {
    Section("Attributes") {
      if let analysis = model.analysis {
        DilemmaAttributesContent(entry: model.entry, analysis: analysis)
      } else {
        Text("No saved analysis is available for this entry.")
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct LikelyChoiceAdvicePanel: View {
  let advice: LikelyChoiceAdvice?
  let status: LikelyChoiceAdviceStatus
  let optionTitles: [Int: String]
  let recordedChoiceTitle: String?
  let showsRecordedChoice: Bool

  var body: some View {
    if showsRecordedChoice, let recordedChoiceTitle {
      recordedChoiceView(recordedChoiceTitle)
    } else {
      switch status {
      case .available:
        if let advice {
          adviceView(advice)
        } else {
          unavailableView
        }
      case .notEnoughMarkedSimilarDilemmas:
        Text("Not enough marked similar dilemmas yet.")
          .foregroundStyle(.secondary)
      case .noSimilarDilemmas:
        Text("Similar dilemmas appear after more analyzed entries are saved.")
          .foregroundStyle(.secondary)
      case .noAnalysis:
        Text("No saved analysis is available for this entry.")
          .foregroundStyle(.secondary)
      case .unavailable:
        unavailableView
      }
    }
  }

  private func recordedChoiceView(_ title: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Choice recorded", systemImage: "checkmark.circle.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.tint)
      Text(title)
        .font(.headline)
        .lineLimit(3)
      Text("Open analysis to review similar-dilemma support.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 6)
  }

  private func adviceView(_ advice: LikelyChoiceAdvice) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        if let optionIndex = advice.optionIndex {
          Text(optionTitle(for: optionIndex))
            .font(.headline)
            .lineLimit(3)
        } else {
          Text("Support is evenly split")
            .font(.headline)
        }

        Text(sourceText(for: advice.decidedDilemmaCount))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      SupportRowsView(rows: supportRows(for: advice))
    }
    .padding(.vertical, 8)
  }

  private var unavailableView: some View {
    Text("Not enough data to build a hint yet.")
      .foregroundStyle(.secondary)
  }

  private func optionTitle(for optionIndex: Int) -> String {
    optionTitles[optionIndex] ?? String(localized: "Option \(optionIndex)")
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

  private func sourceText(for count: Int) -> LocalizedStringKey {
    if count == 1 {
      return "Based on 1 marked similar dilemma"
    }
    return "Based on \(count) marked similar dilemmas"
  }
}

private struct SupportRowsView: View {
  let rows: [SupportRow]

  var body: some View {
    VStack(spacing: 10) {
      ForEach(rows, id: \.optionIndex) { row in
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

  private func clamped(_ value: Double) -> Double {
    min(max(value, 0), 1)
  }
}

private struct SimilarDilemmasSection<Destination: View>: View {
  let matches: [SimilarDilemma]
  let destination: (SimilarDilemma) -> Destination

  init(
    matches: [SimilarDilemma],
    @ViewBuilder destination: @escaping (SimilarDilemma) -> Destination
  ) {
    self.matches = matches
    self.destination = destination
  }

  var body: some View {
    Section("Similar Dilemmas") {
      if matches.isEmpty {
        Text("Similar dilemmas appear after more analyzed entries are saved.")
          .foregroundStyle(.secondary)
      } else {
        ForEach(matches) { match in
          NavigationLink {
            destination(match)
          } label: {
            SimilarDilemmaRow(match: match)
          }
        }
      }
    }
  }
}

private struct SimilarDilemmaRow: View {
  let match: SimilarDilemma

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(match.entry.rawText)
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text(match.score.formatted(.percent.precision(.fractionLength(0))))
          .font(.caption.monospacedDigit().weight(.semibold))
          .foregroundStyle(.secondary)
      }

      Text(match.entry.options.map(\.title).joined(separator: " / "))
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)

      if let recordedChoiceTitle = match.recordedChoiceTitle {
        RecordedChoiceTableRow(optionTitle: recordedChoiceTitle)
      }
    }
    .padding(.vertical, 3)
  }
}

private struct DilemmaAttributesContent: View {
  let entry: DiaryEntry
  let analysis: DecisionAnalysis

  var body: some View {
    ForEach(entry.options) { option in
      let attributes = topAttributes(for: option)

      VStack(alignment: .leading, spacing: 8) {
        Text(option.title)
          .font(.subheadline.weight(.semibold))
        if attributes.isEmpty {
          Text("No non-zero attributes for this option.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(attributes) { attribute in
            HStack {
              Text(TaxonomyLocalization.attributeName(
                attributeID: attribute.attribute.attributeID,
                fallback: attribute.attribute.name
              ))
              .lineLimit(2)
              Spacer()
              Text(format(Double(attribute.score)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(scoreColor(Double(attribute.score)))
            }
          }
        }
      }
    }
  }

  private func topAttributes(for option: DiaryOption) -> [AttributeProfileScore] {
    analysis.optionAttributeProfiles
      .first { $0.optionIndex == option.index }?
      .strongestSignedAttributes() ?? []
  }

  private func format(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(3)))
  }

  private func scoreColor(_ score: Double) -> Color {
    score > 0 ? .green : .red
  }
}

private struct DilemmaClustersContent: View {
  let entry: DiaryEntry
  let analysis: DecisionAnalysis

  var body: some View {
    ForEach(entry.options) { option in
      let clusters = topClusters(for: option)

      VStack(alignment: .leading, spacing: 8) {
        Text(option.title)
          .font(.subheadline.weight(.semibold))
        if clusters.isEmpty {
          Text("No non-zero clusters for this option.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
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
  }

  private func topClusters(for option: DiaryOption) -> [ClusterProfile] {
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

  private func format(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(3)))
  }

  private func scoreColor(_ score: Double) -> Color {
    score > 0 ? .green : .red
  }
}

private struct SupportRow {
  let optionIndex: Int
  let title: String
  let support: Double
}
