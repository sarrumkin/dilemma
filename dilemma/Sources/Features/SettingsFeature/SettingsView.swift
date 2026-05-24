import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var model: DilemmaAppModel
  @State private var exportURL: URL?
  @State private var showingDeleteConfirmation = false

  var body: some View {
    NavigationStack {
      List {
        Section("Lock") {
          Toggle("Require Face ID or passcode", isOn: $model.requiresDeviceUnlock)
        }

        Section("Export") {
          Button {
            do {
              exportURL = try model.makeExportFile()
            } catch {
              model.errorMessage = error.localizedDescription
            }
          } label: {
            Label("Prepare JSON export", systemImage: "square.and.arrow.up")
          }
          .accessibilityIdentifier("prepare-export-button")

          if let exportURL {
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
          }
          .accessibilityIdentifier("delete-all-data-button")
        }

        Section("Privacy") {
          Label("Analysis runs locally.", systemImage: "checkmark.shield")
          Label("Dilemma text is not sent to a server.", systemImage: "wifi.slash")
          Label("Model and assets are bundled locally.", systemImage: "shippingbox")
        }

        if let errorMessage = model.errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle("Privacy")
      .confirmationDialog(
        "Delete all entries, analysis results, feedback, and local diary settings?",
        isPresented: $showingDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("Delete all user data", role: .destructive) {
          model.deleteAllUserData()
          exportURL = nil
        }
        .accessibilityIdentifier("confirm-delete-all-data-button")
        Button("Cancel", role: .cancel) {}
      }
    }
  }
}
