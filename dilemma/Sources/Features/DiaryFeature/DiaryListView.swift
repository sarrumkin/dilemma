import DecisionModels
import SwiftUI

struct DiaryListView: View {
  let model: DiaryListModel
  let makeNewEntryModel: () -> NewEntryModel
  let makeJSONImportModel: () -> DilemmaJSONImportModel
  let onDeleted: () -> Void
  let makeAnalysisDetailModel: (DiaryEntry, DiaryAnalysis?) -> AnalysisDetailModel
  @State private var isCreatingEntry = false
  @State private var isImportingJSON = false
  @State private var pendingDeleteEntry: DiaryEntry?

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
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                  pendingDeleteEntry = entry
                } label: {
                  Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("delete-entry-button-\(entry.id.uuidString)")
              }
            }
          }
        }
      }
      .navigationTitle("Dilemma")
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {
            isImportingJSON = true
          } label: {
            Label("Import JSON", systemImage: "tray.and.arrow.down")
          }
          .accessibilityIdentifier("import-json-button")

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
      .sheet(isPresented: $isImportingJSON) {
        JSONImportSheet(isPresented: $isImportingJSON, model: makeJSONImportModel())
      }
      .confirmationDialog(
        "Delete this dilemma, its analysis, and feedback?",
        isPresented: deleteConfirmationBinding,
        titleVisibility: .visible
      ) {
        Button("Delete", role: .destructive) {
          guard let entry = pendingDeleteEntry else { return }
          if model.delete(entry) {
            onDeleted()
          }
          pendingDeleteEntry = nil
        }
        .accessibilityIdentifier("confirm-delete-entry-button")
        Button("Cancel", role: .cancel) {
          pendingDeleteEntry = nil
        }
      }
    }
  }

  private var deleteConfirmationBinding: Binding<Bool> {
    Binding(get: {
      pendingDeleteEntry != nil
    }, set: { isPresented in
      if !isPresented {
        pendingDeleteEntry = nil
      }
    })
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

private struct JSONImportSheet: View {
  @Binding var isPresented: Bool
  @State private var model: DilemmaJSONImportModel

  init(isPresented: Binding<Bool>, model: DilemmaJSONImportModel) {
    self._isPresented = isPresented
    self._model = State(initialValue: model)
  }

  var body: some View {
    DilemmaJSONImportView(model: model, isPresented: $isPresented)
  }
}

private struct DilemmaJSONImportView: View {
  @Bindable var model: DilemmaJSONImportModel
  @Binding var isPresented: Bool

  var body: some View {
    NavigationStack {
      Form {
        Section("JSON") {
          TextEditor(text: $model.jsonText)
            .font(.body.monospaced())
            .frame(minHeight: 240)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("json-import-text-editor")
        }

        if let errorMessage = model.errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle("Import JSON")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            isPresented = false
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task {
              if await model.importDrafts() {
                isPresented = false
              }
            }
          } label: {
            Label("Import", systemImage: "tray.and.arrow.down")
          }
          .disabled(!model.canImport)
          .accessibilityIdentifier("run-json-import-button")
        }
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
        (
          Text("\(analysis.attributeConflicts.count) ")
            + Text("conflicts")
            + Text(" • \(analysis.modelID)")
        )
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.vertical, 4)
  }
}
