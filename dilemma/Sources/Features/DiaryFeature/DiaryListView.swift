import DecisionModels
import SwiftUI

struct DiaryListView: View {
  let model: DiaryListModel
  let makeNewEntryModel: () -> NewEntryModel
  let makeAnalysisDetailModel: (DiaryEntry, DiaryAnalysis?) -> AnalysisDetailModel
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
                AnalysisDetailView(
                  model: makeAnalysisDetailModel(entry, model.latestAnalysis(for: entry))
                )
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
          .accessibilityIdentifier("new-entry-button")
        }
      }
      .sheet(isPresented: $isCreatingEntry) {
        NewEntrySheet(isPresented: $isCreatingEntry, model: makeNewEntryModel())
      }
    }
  }
}

private struct NewEntrySheet: View {
  @Binding var isPresented: Bool
  @State private var model: NewEntryModel

  init(isPresented: Binding<Bool>, model: NewEntryModel) {
    self._isPresented = isPresented
    self._model = State(initialValue: model)
  }

  var body: some View {
    NewEntryView(model: model, isPresented: $isPresented)
  }
}

private struct EntryRow: View {
  let entry: DiaryEntry
  let analysis: DiaryAnalysis?

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
