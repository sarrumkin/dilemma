import ProjectDescription

let deploymentTarget: DeploymentTargets = .iOS("18.0")

func targetInfoPlist(_ targetName: String) -> InfoPlist {
  .file(path: "\(targetName)/Info.plist")
}

let project = Project(
  name: "dilemma",
  options: .options(
    disableBundleAccessors: true,
    disableSynthesizedResourceAccessors: true
  ),
  packages: [
    .package(url: "https://github.com/jkrukowski/swift-embeddings", from: "0.0.16"),
  ],
  settings: .settings(
    base: [
      "DEVELOPMENT_TEAM": "",
      "SWIFT_VERSION": "6.0",
      "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
    ]
  ),
  targets: [
    .target(
      name: "dilemma",
      destinations: .iOS,
      product: .app,
      bundleId: "com.local.dilemma",
      deploymentTargets: deploymentTarget,
      infoPlist: targetInfoPlist("dilemma"),
      // Buildable folders keep source membership synchronized in Xcode:
      // adding a Swift file under dilemma/Sources does not require
      // regenerating the project just to add a file reference.
      buildableFolders: [
        "dilemma/Sources",
      ],
      dependencies: [
        .target(name: "DecisionKernel"),
      ]
    ),
    .target(
      name: "DecisionKernel",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.local.dilemma.DecisionKernel",
      deploymentTargets: deploymentTarget,
      infoPlist: targetInfoPlist("DecisionKernel"),
      resources: .resources([
        .folderReference(path: "DecisionKernel/Resources/Attributes"),
        .folderReference(path: "DecisionKernel/Resources/Models"),
      ]),
      buildableFolders: [
        "DecisionKernel/Sources",
      ],
      dependencies: [
        .package(product: "Embeddings"),
        .package(product: "MLTensorUtils"),
      ]
    ),
    .target(
      name: "DecisionKernelTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "com.local.dilemma.DecisionKernelTests",
      deploymentTargets: deploymentTarget,
      infoPlist: targetInfoPlist("DecisionKernelTests"),
      buildableFolders: [
        "DecisionKernelTests/Sources",
      ],
      dependencies: [
        .target(name: "DecisionKernel"),
      ]
    ),
  ],
  schemes: [
    .scheme(
      name: "dilemma",
      shared: true,
      buildAction: .buildAction(targets: ["dilemma"]),
      testAction: .targets(["DecisionKernelTests"])
    ),
  ]
)
