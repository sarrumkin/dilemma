import SwiftUI

struct SettingsView: View {
  @Bindable var model: SettingsModel
  let onDeleted: () -> Void
  @State private var showingDeleteConfirmation = false

  var body: some View {
    NavigationStack {
      List {
        Section("Language") {
          Picker("Language", selection: $model.appLanguage) {
            Text("English").tag(AppLanguage.english)
            Text("Russian").tag(AppLanguage.russian)
          }
          .pickerStyle(.segmented)
        }

        Section("Appearance") {
          Toggle("Use dark theme", isOn: $model.usesDarkTheme)
            .accessibilityIdentifier("dark-theme-toggle")
        }

        Section("Privacy") {
          Toggle("Require Face ID or passcode", isOn: $model.requiresDeviceUnlock)
          Label("Analysis runs locally.", systemImage: "checkmark.shield")
          Label("Dilemma text is not sent to a server.", systemImage: "wifi.slash")
          Label("Model, embeddings, and assets are bundled locally.", systemImage: "shippingbox")
        }

        Section("Export") {
          Button {
            model.prepareExportFile()
          } label: {
            Label("Prepare JSON export", systemImage: "square.and.arrow.up")
          }
          .accessibilityIdentifier("prepare-export-button")

          if let exportURL = model.exportURL {
            ShareLink(item: exportURL) {
              Label("Share export", systemImage: "doc")
            }
            .accessibilityIdentifier("share-export-button")
          }
        }

        Section("Delete") {
          Button(role: .destructive) {
            showingDeleteConfirmation = true
          } label: {
            Label("Delete all user data", systemImage: "trash")
              .foregroundStyle(.red)
          }
          .accessibilityIdentifier("delete-all-data-button")
        }

        if let errorMessage = model.errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle("Settings")
      .confirmationDialog(
        "Delete all entries, analysis results, feedback, and local diary settings?",
        isPresented: $showingDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("Delete all user data", role: .destructive) {
          if model.deleteAllUserData() {
            onDeleted()
          }
        }
        .accessibilityIdentifier("confirm-delete-all-data-button")
        Button("Cancel", role: .cancel) {}
      }
    }
  }
}
