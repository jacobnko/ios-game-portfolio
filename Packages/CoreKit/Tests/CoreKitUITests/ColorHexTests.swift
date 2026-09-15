// Checks that hex literals from a design handoff survive the conversion intact.

import Testing
import SwiftUI
@testable import CoreKitUI

@Test func hexSplitsChannelsInTheRightOrder() {
    // A value with three distinct channels: a swapped shift or mask shows up
    // immediately, which 0xFFFFFF or 0x000000 would hide.
    let components = Color.sRGBComponents(hex: 0x1FE3CF)
    #expect(components.red == 31.0 / 255)
    #expect(components.green == 227.0 / 255)
    #expect(components.blue == 207.0 / 255)
}

@Test func hexHandlesTheEndsOfTheRange() {
    let black = Color.sRGBComponents(hex: 0x000000)
    #expect(black.red == 0 && black.green == 0 && black.blue == 0)

    let white = Color.sRGBComponents(hex: 0xFFFFFF)
    #expect(white.red == 1 && white.green == 1 && white.blue == 1)
}

@Test func hexIgnoresBitsAboveTheColourChannels() {
    // A caller writing 0xFF1FE3CF (an ARGB literal by habit) should still get the
    // colour, not a wrapped or shifted one.
    let withAlpha = Color.sRGBComponents(hex: 0xFF1FE3CF)
    let withoutAlpha = Color.sRGBComponents(hex: 0x1FE3CF)
    #expect(withAlpha == withoutAlpha)
}

@Test func theInitialiserPutsEachChannelInTheRightSlot() {
    // Distinct from the component test above: that one checks the bit arithmetic,
    // this one checks the arithmetic is handed to SwiftUI in the right order. A
    // red/blue swap at the call site would pass every test above.
    let fromHex = Color(hex: 0x1FE3CF)
    let expected = Color(.sRGB, red: 31.0 / 255, green: 227.0 / 255, blue: 207.0 / 255, opacity: 1)
    #expect(fromHex == expected)

    // And a channel swap really is observable through Color's equality, so the
    // expectation above is not vacuously true.
    let swapped = Color(.sRGB, red: 207.0 / 255, green: 227.0 / 255, blue: 31.0 / 255, opacity: 1)
    #expect(fromHex != swapped)
}

@Test func theInitialiserIsOpaque() {
    // A colour that silently carried alpha would make the board's glow rule —
    // "the line core is always opaque" — impossible to honour.
    #expect(Color(hex: 0x1FE3CF) == Color(.sRGB, red: 31.0 / 255, green: 227.0 / 255, blue: 207.0 / 255, opacity: 1))
    #expect(Color(hex: 0x1FE3CF) != Color(.sRGB, red: 31.0 / 255, green: 227.0 / 255, blue: 207.0 / 255, opacity: 0.5))
}
