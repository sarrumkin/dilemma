import DiaryVault
import SwiftUI

struct DiaryListView: View {
  @EnvironmentObject private var model: DilemmaAppModel
  @State private var isCreatingEntry = false

  var body: some View {
    NavigationStack {
      List {
        if let errorMessage = model.errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(.red)
          }
        }

        if model.entries.isEmpty {
          ContentUnavailableView(
            "No decisions yet",
            systemImage: "square.and.pencil",
            description: Text("Create a structured dilemma to run local analysis.")
          )
        } else {
          Section("Diary") {
            ForEach(model.entries) { entry in
              NavigationLink {
                AnalysisDetailView(entry: entry, analysis: model.latestAnalysis(for: entry))
              } label: {
                EntryRow(entry: entry, analysis: model.latestAnalysis(for: entry))
              }
            }
          }
        }
      }
      .navigationTitle("Dilemma")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            isCreatingEntry = true
          } label: {
            Label("New entry", systemImage: "plus")
          }
        }
      }
      .sheet(isPresented: $isCreatingEntry) {
        NewEntryView(isPresented: $isCreatingEntry)
          .environmentObject(model)
      }
      .overlay {
        if model.isBusy {
          ProgressView("Analyzing locally")
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
  }
}

private struct EntryRow: View {
  let entry: DiaryEntryRecord
  let analysis: StoredDecisionAnalysis?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(entry.rawText)
        .font(.headline)
        .lineLimit(2)
      Text(entry.options.map(\.title).joined(separator: " / "))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      if let analysis {
        Text("\(analysis.attributeConflicts.count) conflicts • \(analysis.modelID)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.vertical, 4)
  }
}
