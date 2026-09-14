// swift-tools-version: 6.0
import PackageDescription

// Shared foundation for every game in the portfolio.
//
// Target layout is deliberate:
//   CoreKitJuice     - feedback pipeline (haptics, pitched audio, victory VFX). No external dependencies.
//   CoreKitData      - SwiftData + CloudKit progress schema. No external dependencies.
//   CoreKitServices  - AdMob, StoreKit 2, Firebase. All heavy dependencies live here and nowhere else.
//
// Keeping Juice and Data dependency-free is what makes SwiftUI Previews and `swift test` fast.
// Juice code gets tuned dozens of times per game, so preview speed is development speed.
let package = Package(
    name: "CoreKit",
    // macOS is declared so `swift build` / `swift test` run on the host without a simulator.
    // Platform-specific code is guarded with `#if canImport(...)`.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "CoreKitJuice", targets: ["CoreKitJuice"]),
        .library(name: "CoreKitData", targets: ["CoreKitData"]),
        .library(name: "CoreKitServices", targets: ["CoreKitServices"]),
    ],
    dependencies: [
        // Intentionally empty for now.
        // AdMob is added in S1.6 and Firebase in S1.7 — both only as CoreKitServices dependencies.
    ],
    targets: [
        .target(name: "CoreKitJuice"),
        .target(name: "CoreKitData"),
        .target(name: "CoreKitServices", dependencies: ["CoreKitData"]),
        .testTarget(name: "CoreKitJuiceTests", dependencies: ["CoreKitJuice"]),
        .testTarget(name: "CoreKitDataTests", dependencies: ["CoreKitData"]),
    ]
)
