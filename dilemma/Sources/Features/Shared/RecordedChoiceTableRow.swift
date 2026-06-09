import SwiftUI

struct RecordedChoiceTableRow: View {
  let optionTitle: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 5) {
      Image(systemName: "checkmark.circle.fill")
        .imageScale(.medium)
      Text("Recorded choice") + Text(verbatim: ": \(optionTitle)")
    }
    .font(.subheadline.weight(.semibold))
    .foregroundStyle(.tint)
    .lineLimit(nil)
    .fixedSize(horizontal: false, vertical: true)
  }
}
