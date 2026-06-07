import DecisionModels
import Foundation

public struct DecisionAnalysisRunner: Sendable {
  private let bundle: Bundle
  private let modelResourceName: String
  private let assetResourceName: String
  private let clusterMethod: DecisionClusterMethod?

  /// Creates a runner for the built-in smoke draft using a known cluster method.
  public init(
    bundle: Bundle = DecisionKernelResourceBundle.bundle,
    modelResourceName: String = "paraphrase-multilingual-MiniLM-L12-v2",
    clusterMethod: DecisionClusterMethod = .bhatiaWardReddit
  ) {
    self.bundle = bundle
    self.modelResourceName = modelResourceName
    self.assetResourceName = clusterMethod.assetResourceName
    self.clusterMethod = clusterMethod
  }

  /// Creates a runner for the built-in smoke draft using an explicit asset resource name.
  public init(
    bundle: Bundle = DecisionKernelResourceBundle.bundle,
    modelResourceName: String = "paraphrase-multilingual-MiniLM-L12-v2",
    assetResourceName: String
  ) {
    self.bundle = bundle
    self.modelResourceName = modelResourceName
    self.assetResourceName = assetResourceName
    self.clusterMethod = DecisionClusterMethod(assetResourceName: assetResourceName)
  }

  /// Executes the built-in smoke analysis draft through `DecisionAnalysisService`.
  public func run() async throws -> DecisionAnalysis {
    if let clusterMethod {
      return try await DecisionAnalysisService(
        bundle: bundle,
        modelResourceName: modelResourceName,
        clusterMethod: clusterMethod
      ).analyze(Self.defaultDraft)
    }

    return try await DecisionAnalysisService(
      bundle: bundle,
      modelResourceName: modelResourceName,
      assetResourceName: assetResourceName
    ).analyze(Self.defaultDraft)
  }

  /// Stable smoke-test draft used by integration tests and local analysis probes.
  static let defaultDraft = DecisionDraft(
    rawText: "Should I keep the stable path or take the new opportunity?",
    options: [
      DecisionOption(
        index: 1,
        title: "Stay with the stable path",
        reasons: [
          Reason(text: "This option would save me money.", polarity: .benefit),
          Reason(text: "It would give me more time with my family.", polarity: .benefit),
          Reason(text: "It gives me a safer long-term path.", polarity: .benefit),
          Reason(text: "It could limit my career prospects.", polarity: .cost),
          Reason(text: "I might miss useful new skills.", polarity: .cost),
          Reason(text: "It may feel less exciting.", polarity: .cost),
        ]
      ),
      DecisionOption(
        index: 2,
        title: "Take the new opportunity",
        reasons: [
          Reason(text: "It could improve my career prospects.", polarity: .benefit),
          Reason(text: "I would have more independence.", polarity: .benefit),
          Reason(text: "I would learn useful new skills.", polarity: .benefit),
          Reason(text: "There is a chance I could lose stability.", polarity: .cost),
          Reason(text: "It may hurt my mental health.", polarity: .cost),
          Reason(text: "It requires a lot of time and work.", polarity: .cost),
        ]
      ),
    ]
  )
}

enum MemorySnapshot {
  /// Returns the current process resident memory in megabytes, or zero when unavailable.
  static func currentResidentMegabytes() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return 0 }
    return Double(info.resident_size) / 1_048_576
  }
}
