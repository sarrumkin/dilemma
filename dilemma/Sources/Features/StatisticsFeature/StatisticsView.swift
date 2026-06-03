import DecisionModels
import SwiftUI

struct StatisticsView: View {
  let model: StatisticsModel
  let makeAnalysisDetailModel: (DiaryEntry, DiaryAnalysis?) -> AnalysisDetailModel

  var body: some View {
    NavigationStack {
      List {
        Section("Diary") {
          MetricRow(label: "Entries", value: "\(model.statistics.entryCount)")
          MetricRow(label: "Analyzed entries", value: "\(model.clusterStatistics.analyzedEntryCount)")
          MetricRow(label: "Feedback records", value: "\(model.statistics.feedbackCount)")
        }

        Section("Clusters") {
          if model.hasClusterGroups {
            ForEach(model.clusterStatistics.groups) { group in
              NavigationLink {
                ClusterDilemmaListView(
                  group: group,
                  makeAnalysisDetailModel: makeAnalysisDetailModel
                )
              } label: {
                ClusterDilemmaGroupRow(group: group)
              }
              .accessibilityIdentifier("cluster-row-\(group.clusterID)")
            }
          } else {
            Text(clusterEmptyMessage)
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
      .navigationTitle("Statistics")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.reload()
          } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
          }
          .accessibilityIdentifier("refresh-statistics-button")
        }
      }
    }
  }

  private var clusterEmptyMessage: LocalizedStringKey {
    if !model.hasDiaryEntries {
      return "Create or import dilemmas to see cluster statistics."
    }
    if !model.hasAnalyzedEntries {
      return "Cluster statistics appear after saved analysis results."
    }
    return "Cluster groups appear after analyzed entries have non-zero cluster scores."
  }
}

private struct ClusterDilemmaListView: View {
  let group: ClusterDilemmaGroup
  let makeAnalysisDetailModel: (DiaryEntry, DiaryAnalysis?) -> AnalysisDetailModel

  var body: some View {
    List {
      Section("Cluster") {
        Text(group.label)
          .font(.headline)
          .lineLimit(3)
        MetricRow(label: "Dilemmas", value: "\(group.count)")
      }

      Section("Dilemmas") {
        ForEach(group.records) { record in
          NavigationLink {
            AnalysisDetailView(
              model: makeAnalysisDetailModel(record.entry, record.analysis)
            )
          } label: {
            ClusterDilemmaRecordRow(record: record)
          }
          .accessibilityIdentifier("cluster-entry-row-\(record.entry.id.uuidString)")
        }
      }
    }
    .navigationTitle("Cluster")
  }
}

private struct ClusterDilemmaGroupRow: View {
  let group: ClusterDilemmaGroup

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text(group.label)
          .font(.subheadline.weight(.semibold))
          .lineLimit(2)

        if let strongestRecord = group.strongestRecord {
          Text(strongestRecord.entry.rawText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      Spacer(minLength: 12)

      VStack(alignment: .trailing, spacing: 2) {
        Text("\(group.count)")
          .font(.body.monospacedDigit().weight(.semibold))
        Text("dilemmas")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 3)
  }
}

private struct ClusterDilemmaRecordRow: View {
  let record: ClusterDilemmaRecord

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(record.entry.rawText)
        .font(.subheadline.weight(.semibold))
        .lineLimit(2)

      Text(record.entry.options.map(\.title).joined(separator: " / "))
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)

      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(affectedOptionTitles)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Spacer(minLength: 12)

        Text(format(record.strongestScore))
          .font(.caption.monospacedDigit().weight(.semibold))
          .foregroundStyle(scoreColor(record.strongestScore))
      }
    }
    .padding(.vertical, 3)
  }

  private var affectedOptionTitles: String {
    record.optionIndices.map { optionIndex in
      record.entry.options.first { $0.index == optionIndex }?.title ?? "Option \(optionIndex)"
    }
    .joined(separator: " • ")
  }

  private func format(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(3)))
  }

  private func scoreColor(_ score: Double) -> Color {
    score > 0 ? .green : .red
  }
}

private struct MetricRow: View {
  let label: LocalizedStringKey
  let value: String

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      Text(value)
        .font(.body.monospacedDigit())
        .foregroundStyle(.secondary)
    }
  }
}
