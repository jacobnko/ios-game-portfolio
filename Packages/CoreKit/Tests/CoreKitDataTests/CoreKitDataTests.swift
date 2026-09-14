// Guards the persistence layer's public contract.

import Testing
@testable import CoreKitData

@Test func schemaVersionIsDeclared() {
    #expect(CoreKitData.schemaVersion.isEmpty == false)
}
