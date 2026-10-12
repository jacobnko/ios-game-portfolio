// Outlines for each ParticleShape, and one Canvas pass that draws a whole burst.

import SwiftUI

public extension ParticleShape {
    /// The outline centred on the origin, longest side `length`, unrotated.
    func path(length: CGFloat) -> Path {
        let l = length
        switch self {
        case .dot:
            return Path(ellipseIn: CGRect(x: -l / 2, y: -l / 2, width: l, height: l))
        case .square:
            return Path(CGRect(x: -l / 2, y: -l / 2, width: l, height: l))
        case .triangle:
            // Scalene on purpose: an equilateral shard reads as an icon, not as glass.
            return polygon([(-0.50, 0.38), (0.50, 0.26), (-0.12, -0.42)], scale: l)
        case .parallelogram:
            return polygon([(-0.50, 0.35), (0.30, 0.35), (0.50, -0.35), (-0.30, -0.35)], scale: l)
        case .sliver:
            return polygon([(-0.50, 0.125), (0.50, 0.06), (0.50, -0.125), (-0.50, -0.06)], scale: l)
        }
    }

    /// The first edge of the outline, for a one-sided highlight that sells "glass".
    func highlightEdge(length: CGFloat) -> Path? {
        let l = length
        let points: [(CGFloat, CGFloat)]
        switch self {
        case .dot, .square: return nil
        case .triangle: points = [(-0.12, -0.42), (0.50, 0.26)]
        case .parallelogram: points = [(-0.30, -0.35), (0.50, -0.35)]
        case .sliver: points = [(-0.50, -0.06), (0.50, -0.125)]
        }
        var path = Path()
        path.move(to: CGPoint(x: points[0].0 * l, y: points[0].1 * l))
        path.addLine(to: CGPoint(x: points[1].0 * l, y: points[1].1 * l))
        return path
    }

    private func polygon(_ points: [(CGFloat, CGFloat)], scale: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: points[0].0 * scale, y: points[0].1 * scale))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.0 * scale, y: point.1 * scale))
        }
        path.closeSubpath()
        return path
    }
}

public extension ParticleField {
    /// Draws every live particle into a `Canvas` in one pass.
    ///
    /// One Canvas for the whole burst, never a View per particle — views collapse the
    /// frame rate past a few dozen. Unit space maps onto `reference`, a rect in the
    /// canvas (typically the board), so a burst defined in fractions of the board
    /// lands on the board at any device size.
    ///
    /// Expects particles from `emit`, whose `size` is in unit space like everything
    /// else. The legacy `make` burst sizes its dots in points and draws itself.
    ///
    /// - Parameters:
    ///   - minimumLength: floor in points for a particle's longest side, so shards on a
    ///     small reference never shrink below what reads on screen.
    ///   - highlight: colour of the one-sided edge on shard shapes, or `nil` for none.
    static func draw(
        _ particles: [Particle],
        in context: GraphicsContext,
        reference: CGRect,
        at time: TimeInterval,
        gravity: Double = defaultGravity,
        palette: [Color],
        minimumLength: CGFloat = 0,
        highlight: Color? = nil
    ) {
        guard !palette.isEmpty else { return }
        for particle in particles {
            guard let unit = position(of: particle, at: time, gravity: gravity) else { continue }
            let alpha = opacity(of: particle, at: time)
            guard alpha > 0.01 else { continue }

            let length = max(minimumLength, particle.size * reference.width * CGFloat(scale(of: particle, at: time)))
            let transform = CGAffineTransform(rotationAngle: CGFloat(rotation(of: particle, at: time)))
                .concatenating(CGAffineTransform(
                    translationX: reference.minX + unit.x * reference.width,
                    y: reference.minY + unit.y * reference.height
                ))
            let color = palette[particle.colorIndex % palette.count]
            context.fill(particle.shape.path(length: length).applying(transform), with: .color(color.opacity(alpha)))
            if let highlight, let edge = particle.shape.highlightEdge(length: length) {
                context.stroke(edge.applying(transform), with: .color(highlight.opacity(alpha)), lineWidth: 1)
            }
        }
    }
}
