import SwiftUI

struct NewEntryView: View {
  @EnvironmentObject private var model: DilemmaAppModel
  @Binding var isPresented: Bool
  @State private var input = EntryFormInput()

  var body: some View {
    NavigationStack {
      Form {
        Section("Dilemma") {
          TextEditor(text: $input.rawText)
            .frame(minHeight: 96)
            .accessibilityLabel("Dilemma text")
        }

        OptionEditorSection(
          title: "Option 1",
          optionTitle: $input.option1Title,
          benefits: $input.option1Benefits,
          costs: $input.option1Costs
        )

        OptionEditorSection(
          title: "Option 2",
          optionTitle: $input.option2Title,
          benefits: $input.option2Benefits,
          costs: $input.option2Costs
        )

        if !input.isValid {
          Section {
            Text("Fill the dilemma, both options, and three benefits and costs for each option.")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle("New Entry")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            isPresented = false
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task {
              await model.createAnalyzeAndSave(input)
              if model.errorMessage == nil {
                isPresented = false
              }
            }
          } label: {
            Label("Analyze", systemImage: "waveform.path.ecg")
          }
          .disabled(!input.isValid || model.isBusy)
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
