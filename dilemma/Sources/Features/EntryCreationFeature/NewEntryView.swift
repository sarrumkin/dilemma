import SwiftUI

struct NewEntryView: View {
  @Bindable var model: NewEntryModel
  @Binding var isPresented: Bool

  var body: some View {
    NavigationStack {
      Form {
        Section("Dilemma") {
          TextEditor(text: $model.command.rawText)
            .frame(minHeight: 96)
            .accessibilityLabel("Dilemma text")
        }

        OptionEditorSection(
          title: "Option 1",
          optionTitle: $model.command.option1Title,
          benefits: $model.command.option1Benefits,
          costs: $model.command.option1Costs
        )

        OptionEditorSection(
          title: "Option 2",
          optionTitle: $model.command.option2Title,
          benefits: $model.command.option2Benefits,
          costs: $model.command.option2Costs
        )

        if !model.command.isValid {
          Section {
            Text("Fill the dilemma, both options, and three benefits and costs for each option.")
              .font(.callout)
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
      .navigationTitle("New Entry")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            isPresented = false
          }
          .accessibilityIdentifier("cancel-entry-button")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task {
              if await model.analyze() {
                isPresented = false
              }
            }
          } label: {
            Label("Analyze", systemImage: "waveform.path.ecg")
          }
          .disabled(!model.command.isValid || model.isBusy)
          .accessibilityIdentifier("analyze-entry-button")
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

private struct OptionEditorSection: View {
  let title: String
  @Binding var optionTitle: String
  @Binding var benefits: [String]
  @Binding var costs: [String]

  var body: some View {
    Section(title) {
      TextField("Option title", text: $optionTitle)
        .textInputAutocapitalization(.sentences)

      ReasonGroup(title: "Benefits", values: $benefits)
      ReasonGroup(title: "Costs", values: $costs)
    }
  }
}

private struct ReasonGroup: View {
  let title: String
  @Binding var values: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline.weight(.semibold))
      ForEach(values.indices, id: \.self) { index in
        TextField("\(title.dropLast()) \(index + 1)", text: $values[index], axis: .vertical)
          .lineLimit(1...3)
          .textInputAutocapitalization(.sentences)
      }
    }
    .padding(.vertical, 4)
  }
}
