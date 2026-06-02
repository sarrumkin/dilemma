import SwiftUI

struct StatisticsView: View {
  let model: StatisticsModel

  var body: some View {
    NavigationStack {
      List {
        Section("Diary") {
          MetricRow(label: "Entries", value: "\(model.statistics.entryCount)")
          MetricRow(label: "Feedback records", value: "\(model.statistics.feedbackCount)")
        }

        Section("Chosen Cluster Ranking") {
          if model.statistics.mostFrequentClusters.isEmpty {
            Text("Cluster statistics appear after a decision is saved for an analyzed dilemma.")
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
