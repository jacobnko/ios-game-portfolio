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
        // iOS only: pulls in the AdMob SDK. Host tests never depend on it.
        .library(name: "CoreKitAdsGoogle", targets: ["CoreKitAdsGoogle"]),
    ],
    dependencies: [
        // Only CoreKitAdsGoogle depends on this. Keeping it off CoreKitServices is
        // what lets `swift test` keep running on the host, where an iOS-only
        // binary framework cannot link.
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "13.9.0"),
    ],
    targets: [
        .target(name: "CoreKitJuice"),
        .target(name: "CoreKitData"),
        .target(name: "CoreKitServices", dependencies: ["CoreKitData"]),
        .target(name: "CoreKitAdsGoogle", dependencies: [
            "CoreKitServices",
            .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
        ]),
        .testTarget(name: "CoreKitJuiceTests", dependencies: ["CoreKitJuice"]),
        .testTarget(name: "CoreKitDataTests", dependencies: ["CoreKitData"]),
        .testTarget(name: "CoreKitServicesTests", dependencies: ["CoreKitServices"]),
    ]
)
