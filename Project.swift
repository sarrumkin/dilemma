import ProjectDescription

let deploymentTarget: DeploymentTargets = .iOS("18.0")

let project = Project(
  name: "dilemma",
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
      infoPlist: .file(path: "dilemma/Sources/Info.plist"),
      // Buildable folders keep source membership synchronized in Xcode:
      // adding a Swift file under dilemma/Sources does not require
      // regenerating the project just to add a file reference.
      buildableFolders: [
        .folder(
          "dilemma/Sources",
          exceptions: [
            .exception(excluded: [
              "Info.plist",
              "file.txt",
            ]),
          ]
        ),
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
      infoPlist: .default,
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
      infoPlist: .default,
      buildableFolders: [
        "DecisionKernelTests",
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
