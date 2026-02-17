// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "AgentPiCore",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "AgentPiCore",
      targets: ["AgentPiCore"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/jamesrochabrun/ClaudeCodeSDK", exact: "1.2.4"),
    .package(path: "../PierreDiffsSwift"),
    .package(url: "https://github.com/jamesrochabrun/SwiftTerm", branch: "fix/package-manifest-trailing-commas"),
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),
    .package(url: "https://github.com/groue/GRDB.swift", from: "6.24.0"),
    .package(url: "https://github.com/appstefan/HighlightSwift", from: "1.1.0"),
    .package(url: "https://github.com/jpsim/Yams", from: "5.0.0"),
  ],
  targets: [
    .target(
      name: "AgentPiCore",
      dependencies: [
        .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK"),
        .product(name: "PierreDiffsSwift", package: "PierreDiffsSwift"),
        .product(name: "SwiftTerm", package: "SwiftTerm"),
        .product(name: "MarkdownUI", package: "swift-markdown-ui"),
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "HighlightSwift", package: "HighlightSwift"),
        .product(name: "Yams", package: "Yams"),
      ],
      path: "Sources/AgentPi",
      resources: [
        .process("Resources"),
        .copy("Design/Theme/BundledThemes")
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "AgentPiCoreTests",
      dependencies: ["AgentPiCore"],
      path: "Tests/AgentPiCoreTests"
    ),
  ]
)
