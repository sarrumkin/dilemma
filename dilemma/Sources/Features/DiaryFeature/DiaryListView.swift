import DecisionModels
import DecisionUseCases
import SwiftUI
import UniformTypeIdentifiers

struct DiaryListView: View {
  let model: DiaryListModel
  let makeNewEntryModel: () -> NewEntryModel
  let makeJSONImportModel: () -> DilemmaJSONImportModel
  let onDeleted: () -> Void
  let makeAnalysisDetailModel: (DiaryEntry, DiaryAnalysis?) -> AnalysisDetailModel
  @State private var visibleEntryLimit = Self.entryPageSize
  @State private var isCreatingEntry = false
  @State private var isImportingJSON = false
  @State private var pendingDeleteEntry: DiaryEntry?

  private static let entryPageSize = 30

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
          Section {
            ForEach(visibleEntries) { entry in
              let analysis = model.latestAnalysis(for: entry)
              NavigationLink {
                AnalysisDetailView(
                  model: makeAnalysisDetailModel(entry, analysis)
                )
              } label: {
                EntryRow(entry: entry, analysis: analysis)
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

            if hasMoreEntries {
              ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .onAppear {
                  showMoreEntries()
                }
            }
          }
        }
      }
      .navigationTitle("Diary")
      .onChange(of: model.entries.map(\.id)) { _, _ in
        visibleEntryLimit = min(max(visibleEntryLimit, Self.entryPageSize), model.entries.count)
      }
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

  private var visibleEntries: ArraySlice<DiaryEntry> {
    model.entries.prefix(visibleEntryLimit)
  }

  private var hasMoreEntries: Bool {
    visibleEntryLimit < model.entries.count
  }

  private func showMoreEntries() {
    visibleEntryLimit = min(visibleEntryLimit + Self.entryPageSize, model.entries.count)
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
  @State private var isChoosingFile = false
  @State private var isShowingFormatInfo = false

  var body: some View {
    NavigationStack {
      Form {
        Section("File") {
          Button {
            isChoosingFile = true
          } label: {
            Label("Choose JSON file", systemImage: "doc.badge.plus")
          }
          .disabled(model.isBusy)
          .accessibilityIdentifier("choose-json-file-button")

          Button {
            isShowingFormatInfo = true
          } label: {
            Label("Info", systemImage: "info.circle")
          }
          .accessibilityIdentifier("json-import-info-button")
        }

        Section("Paste JSON") {
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

        if model.isBusy {
          Section {
            ImportProgressLoader(progress: model.importProgress)
          }
        }
      }
      .navigationTitle("Import JSON")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            isPresented = false
          }
          .disabled(model.isBusy)
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
      .fileImporter(
        isPresented: $isChoosingFile,
        allowedContentTypes: [.json]
      ) { result in
        switch result {
        case .success(let url):
          Task {
            if await model.importDrafts(from: url) {
              isPresented = false
            }
          }
        case .failure(let error):
          model.errorMessage = AppErrorMessage.message(for: error, context: .importJSON)
        }
      }
      .sheet(isPresented: $isShowingFormatInfo) {
        JSONImportFormatInfoView()
      }
    }
  }
}

private struct ImportProgressLoader: View {
  let progress: DilemmaDraftImportProgress?

  private var hasKnownTotal: Bool {
    progress?.totalCount ?? 0 > 0
  }

  private var completedCount: Int {
    progress?.completedCount ?? 0
  }

  private var totalCount: Int {
    progress?.totalCount ?? 0
  }

  private var percentText: String {
    guard hasKnownTotal else { return "0%" }
    return "\(Int((progress?.fractionCompleted ?? 0) * 100))%"
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "tray.and.arrow.down")
        .font(.title3)
        .foregroundStyle(.tint)
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline) {
          if hasKnownTotal {
            Text("Analyzing locally")
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
          } else {
            Text("Preparing import")
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
          }

          Spacer(minLength: 12)

          Text(percentText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }

        VStack(alignment: .leading, spacing: 6) {
          ProgressView(value: progress?.fractionCompleted ?? 0, total: 1)
            .progressViewStyle(.linear)
            .accessibilityIdentifier("json-import-progress-loader")

          if hasKnownTotal {
            Text("Imported \(completedCount) of \(totalCount) dilemmas")
              .accessibilityIdentifier("json-import-progress-count")
          } else {
            Text("Reading and validating the JSON file")
              .accessibilityIdentifier("json-import-progress-count")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
      }
    }
    .padding(.vertical, 6)
  }
}

private struct JSONImportFormatInfoView: View {
  @Environment(\.dismiss) private var dismiss

  private let exampleJSON = """
[
  {
    "schemaVersion": 1,
    "rawText": "Should I accept the promotion or keep the calmer role?",
    "options": [
      {
        "title": "Accept the promotion",
        "benefits": [
          "Higher salary",
          "More influence",
          "Career growth"
        ],
        "costs": [
          "More stress",
          "Less free time",
          "Higher responsibility"
        ]
      },
      {
        "title": "Keep the calmer role",
        "benefits": [
          "Stable schedule",
          "Lower stress",
          "More personal time"
        ],
        "costs": [
          "Slower growth",
          "Lower salary",
          "Fewer leadership chances"
        ]
      }
    ]
  }
]
"""

  var body: some View {
    NavigationStack {
      Form {
        Section("Required JSON format") {
          Text("The file must be a JSON array. Each item needs schemaVersion, rawText, and exactly two options. Each option needs title, benefits, and costs.")
        }

        Section("Example") {
          ScrollView(.horizontal) {
            Text(exampleJSON)
              .font(.caption.monospaced())
              .textSelection(.enabled)
          }
        }
      }
      .navigationTitle("Info")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Close") {
            dismiss()
          }
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
