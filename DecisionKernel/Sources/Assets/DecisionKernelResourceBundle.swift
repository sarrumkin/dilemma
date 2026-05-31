import Foundation

private final class DecisionKernelBundleToken {}

public enum DecisionKernelResourceBundle {
  /// Framework bundle that contains DecisionKernel models and attribute assets.
  public static var bundle: Bundle {
    // Resources live inside the DecisionKernel framework bundle. Keeping this
    // accessor in source keeps the project navigator free of generated helpers.
    Bundle(for: DecisionKernelBundleToken.self)
  }
}
