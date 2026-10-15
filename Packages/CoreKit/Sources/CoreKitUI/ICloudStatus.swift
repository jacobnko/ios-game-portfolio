// Whether progress can sync through the player's iCloud, as a row can explain it.

#if canImport(CloudKit)
import CloudKit
#endif

/// iCloud account state reduced to what a settings row says.
public enum ICloudStatus: Equatable, Sendable {
    /// Signed in; SwiftData mirrors progress to the private database.
    case on
    /// No account, or iCloud is off for this app — progress stays on this device.
    case off
    /// Parental controls or device management forbid it.
    case restricted
    /// Signed in but iCloud cannot be reached right now; sync resumes by itself.
    case unavailable

    public var isSyncing: Bool { self == .on }

    #if canImport(CloudKit)
    public init(_ status: CKAccountStatus) {
        switch status {
        case .available: self = .on
        case .noAccount: self = .off
        case .restricted: self = .restricted
        case .temporarilyUnavailable, .couldNotDetermine: self = .unavailable
        @unknown default: self = .unavailable
        }
    }

    /// Asks CloudKit. Only call this from an app that has the iCloud capability for
    /// `containerIdentifier` — creating a container without the entitlement traps.
    /// `fetch` is the CloudKit call; tests pass their own.
    public static func current(
        containerIdentifier: String,
        fetch: @Sendable (String) async throws -> CKAccountStatus = { try await CKContainer(identifier: $0).accountStatus() }
    ) async -> ICloudStatus {
        do {
            return ICloudStatus(try await fetch(containerIdentifier))
        } catch {
            return .unavailable
        }
    }
    #endif
}
