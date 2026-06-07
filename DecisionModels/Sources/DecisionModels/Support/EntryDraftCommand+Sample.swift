extension EntryDraftCommand {
  static func sample() -> EntryDraftCommand {
    EntryDraftCommand(
      rawText: "Should I stay or leave?",
      option1Title: "Stay",
      option2Title: "Leave",
      option1Benefits: ["Stable income", "Close to family", "Lower risk"],
      option1Costs: ["Less growth", "Boredom", "Missed opportunity"],
      option2Benefits: ["Career growth", "New skills", "Independence"],
      option2Costs: ["Financial risk", "Stress", "Less family time"]
    )
  }
}
