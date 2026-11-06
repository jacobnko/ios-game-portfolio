// Checks the appearance choice maps to the right colour scheme and keeps its stored names.

import Testing
import SwiftUI
@testable import CoreKitUI

@Test func eachChoiceMapsToItsColourScheme() {
    #expect(AppearanceChoice.system.colorScheme == nil)
    #expect(AppearanceChoice.light.colorScheme == .light)
    #expect(AppearanceChoice.dark.colorScheme == .dark)
}

@Test func theStoredNamesNeverChange() {
    // Saved settings are read back by these strings; renaming a case would reset every player's choice.
    #expect(AppearanceChoice.allCases.map(\.rawValue) == ["system", "light", "dark"])
    #expect(AppearanceChoice(rawValue: "unknown") == nil)
}

