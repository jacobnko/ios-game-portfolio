// Renders a burst off screen to check the one-pass Canvas drawing actually paints.

import Testing
import SwiftUI
@testable import CoreKitJuice

#if canImport(AppKit)
@MainActor
private func paintedPixels(at time: TimeInterval, highlight: Color?) -> Int {
    let emitter = ParticleEmitter(origins: [CGPoint(x: 0.5, y: 0.5)], spread: Double.pi, speed: 0.2...0.3,
                                  angularSpeed: 1...2, lifetime: 1...1, size: 0.05...0.08,
                                  shapes: [.dot, .square, .triangle, .parallelogram, .sliver])
    let particles = ParticleField.emit(emitter, count: 40, seed: 3)
    let canvas = Canvas { context, size in
        ParticleField.draw(particles, in: context, reference: CGRect(origin: .zero, size: size), at: time,
                           palette: [.red, .green], minimumLength: 2, highlight: highlight)
    }
    .frame(width: 100, height: 100)
    guard let image = ImageRenderer(content: canvas).cgImage,
          let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return -1 }
    let stride = image.bytesPerRow, alphaOffset = image.alphaInfo == .premultipliedFirst || image.alphaInfo == .first ? 0 : 3
    var painted = 0
    for y in 0..<image.height {
        for x in 0..<image.width where bytes[y * stride + x * 4 + alphaOffset] > 0 { painted += 1 }
    }
    return painted
}

@MainActor
@Test func aLiveBurstPaintsTheCanvas() {
    #expect(paintedPixels(at: 0.2, highlight: .white) > 20)
    #expect(paintedPixels(at: 0.2, highlight: nil) > 20)
}

@MainActor
@Test func aBurstPastItsLifetimePaintsNothing() {
    #expect(paintedPixels(at: 5, highlight: .white) == 0)
}
#endif
