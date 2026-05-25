import SwiftUI

struct StatisticsView: View {
  @EnvironmentObject private var model: DilemmaAppModel

  var body: some View {
    NavigationStack {
      List {
        Section("Diary") {
          MetricRow(label: "Entries", value: "\(model.statistics.entryCount)")
          MetricRow(label: "Feedback records", value: "\(model.statistics.feedbackCount)")
        }

        Section("Conflict Feedback") {
          MetricRow(label: "Useful", value: "\(model.statistics.acceptedConflictCount)")
          MetricRow(label: "Not useful", value: "\(model.statistics.rejectedConflictCount)")
        }

        Section("Frequent Clusters") {
          if model.statistics.mostFrequentClusters.isEmpty {
            Text("Cluster statistics appear after saved analysis results.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(model.statistics.mostFrequentClusters) { cluster in
              HStack(alignment: .firstTextBaseline) {
                Text(cluster.label)
                  .lineLimit(2)
                Spacer()
                Text("\(cluster.count)")
                  .font(.body.monospacedDigit())
                  .foregroundStyle(.secondary)
              }
            }
          }
        }

        Section("Recorded Choices") {
          if model.statistics.chosenOptionCounts.isEmpty {
            Text("Choice patterns appear when feedback includes a recorded option.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(model.statistics.chosenOptionCounts.keys.sorted(), id: \.self) { option in
              MetricRow(
                label: "Option \(option)",
                value: "\(model.statistics.chosenOptionCounts[option] ?? 0)"
              )
            }
          }
        }
      }
      .navigationTitle("Statistics")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            do {
              try model.reload()
            } catch {
              model.errorMessage = error.localizedDescription
            }
          } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
          }
          .accessibilityIdentifier("refresh-statistics-button")
        }
      }
    }
  }
}

private struct MetricRow: View {
  let label: String
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
