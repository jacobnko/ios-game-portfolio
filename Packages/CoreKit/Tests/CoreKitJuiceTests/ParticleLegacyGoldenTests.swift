// Freezes the victory burst's existing outputs so particle extensions cannot drift them.

import Testing
import Foundation
import CoreGraphics
@testable import CoreKitJuice

/// Every position and opacity a standard burst produces over its life, hashed bit for bit.
///
/// Captured from the implementation before particles gained rotation, drag, shapes and
/// bounce. A change here means every shipped game's victory payoff now looks different —
/// treat a failure as a regression, never as a value to update.
@Test func legacyBurstIsBitIdentical() {
    let particles = ParticleField.make(count: 24, origins: [CGPoint(x: 0.3, y: 0.6), CGPoint(x: 0.7, y: 0.4)], seed: 0xC0FFEE)
    var values: [Double] = []
    for time in stride(from: 0.0, through: 1.2, by: 0.15) {
        for particle in particles {
            if let point = ParticleField.position(of: particle, at: time) {
                values.append(Double(point.x)); values.append(Double(point.y))
            }
            values.append(ParticleField.opacity(of: particle, at: time))
        }
    }
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    for value in values { hash ^= value.bitPattern; hash &*= 0x0000_0100_0000_01B3 }

    #expect(values.count == 422)
    #expect(hash == 17_348_836_157_046_325_524)
}
