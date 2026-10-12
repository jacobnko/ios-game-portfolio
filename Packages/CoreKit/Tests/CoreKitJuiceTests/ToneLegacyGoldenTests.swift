// Freezes every existing tone's samples so new synthesis features cannot change them.

import Testing
import Foundation
@testable import CoreKitJuice

/// Every sample of the tones shipped games already play, hashed bit for bit.
///
/// Captured before tones gained glides, partials and noise. A change here means
/// every shipped game sounds different — a regression, never a value to update.
@Test func legacyTonesAreBitIdentical() {
    var recipes: [ToneRecipe] = []
    for scale in MusicalScale.allCases {
        for step in 0...12 { recipes.append(ToneRecipe.make(for: .micro, stepIndex: step, scale: scale)) }
    }
    recipes.append(ToneRecipe.make(for: .milestone))
    recipes.append(ToneRecipe.make(for: .error))
    recipes.append(ToneRecipe(frequency: 880, duration: 0.18, gain: 0.5))

    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    var count = 0
    for recipe in recipes {
        for sample in recipe.renderSamples(sampleRate: 44_100) {
            hash ^= UInt64(sample.bitPattern)
            hash &*= 0x0000_0100_0000_01B3
            count += 1
        }
    }
    #expect(count == 219_618)
    #expect(hash == 12_851_489_536_156_170_986)
}
