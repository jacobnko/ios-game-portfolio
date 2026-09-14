// swift-tools-version: 6.0
import PackageDescription

// Firebase adapter for CoreKit's analytics protocols.
//
// This is a SEPARATE package, not a CoreKit target, on purpose. SwiftPM resolves
// every dependency a package declares regardless of which target is being built,
// so putting firebase-ios-sdk in CoreKit would make every build — the harness and
// the fast test loop included — pull roughly 144 MB and wait on a ~100 second
// first resolve. Games that want Firebase depend on this package as well as CoreKit.
let package = Package(
    name: "CoreKitFirebase",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "CoreKitFirebase", targets: ["CoreKitFirebase"]),
    ],
    dependencies: [
        .package(path: "../CoreKit"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.19.1"),
    ],
    targets: [
        .target(name: "CoreKitFirebase", dependencies: [
            .product(name: "CoreKitServices", package: "CoreKit"),
            .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
            .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
        ]),
    ]
)
