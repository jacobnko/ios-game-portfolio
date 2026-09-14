// Entry point for the persistence layer shared by every game.

import Foundation

/// Namespace for the persistence layer.
public enum CoreKitData {
    /// Bumped when the persisted schema changes.
    ///
    /// CloudKit-backed SwiftData models cannot be migrated destructively, so this
    /// value is the trigger for writing an explicit migration plan.
    public static let schemaVersion = "0.1.0"
}
