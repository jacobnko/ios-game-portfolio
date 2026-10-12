// Reproducible random numbers for content that must regenerate identically from a seed.

/// A seeded pseudo-random generator whose every output is defined by this file alone.
///
/// Procedural content keyed by a number (a stage, a daily puzzle) is only meaningful
/// if the same number produces the same content on every device, OS version and
/// Swift release. That rules out three things this type deliberately avoids:
///
/// - `SystemRandomNumberGenerator`, which is not seedable at all.
/// - `Hasher` / `hashValue`, which are randomised per process.
/// - The standard library's `random(in:using:)` and `shuffle(using:)`, whose
///   algorithms are an implementation detail and may change between releases.
///
/// For the last reason this type does **not** conform to `RandomNumberGenerator`:
/// conformance would let a caller pass it to a standard-library algorithm and
/// silently lose the guarantee. Bounded integers, doubles and shuffling are all
/// implemented here and pinned by golden-value tests.
///
/// The core is SplitMix64 (Steele, Lea & Flood, 2014). Not for anything security related.
public struct SeededGenerator: Sendable, Equatable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    /// A generator for one named sub-purpose of a seed.
    ///
    /// Content generation usually has several independent stages (layout, slicing,
    /// ordering). Giving each its own stream means changing how many numbers one
    /// stage draws does not shift every number the later stages see. The label is
    /// mixed in with FNV-1a over its UTF-8 bytes, which is stable everywhere.
    public init(seed: UInt64, stream label: String) {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in label.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        // Run the combination through one SplitMix64 round so nearby seeds with the
        // same label do not produce nearby starting states.
        var mixer = SeededGenerator(seed: seed ^ hash)
        state = mixer.next()
    }

    /// The next 64 uniformly distributed bits.
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform integer in `0..<bound`, without modulo bias.
    ///
    /// Lemire's multiply-and-reject method: one multiplication in the common case,
    /// and a rejection loop only for the small slice of values that would bias the result.
    public mutating func nextInt(below bound: Int) -> Int {
        precondition(bound > 0, "bound must be positive")
        let range = UInt64(bound)
        var product = next().multipliedFullWidth(by: range)
        if product.low < range {
            let threshold = (0 &- range) % range
            while product.low < threshold {
                product = next().multipliedFullWidth(by: range)
            }
        }
        return Int(product.high)
    }

    /// A uniform integer in `range`, inclusive at both ends.
    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let (span, overflow) = range.upperBound.subtractingReportingOverflow(range.lowerBound)
        precondition(!overflow && span < Int.max, "range is too wide")
        return range.lowerBound + nextInt(below: span + 1)
    }

    /// A uniform double in `0..<1` with the full 53 bits of precision.
    public mutating func nextDouble() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    /// A uniform double in `range`.
    public mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextDouble() * (range.upperBound - range.lowerBound)
    }

    /// Shuffles `elements` in place (Fisher–Yates, from the last index down).
    public mutating func shuffle<Element>(_ elements: inout [Element]) {
        guard elements.count > 1 else { return }
        for index in stride(from: elements.count - 1, to: 0, by: -1) {
            let other = nextInt(below: index + 1)
            if other != index {
                elements.swapAt(index, other)
            }
        }
    }

    /// A shuffled copy of `elements`.
    public mutating func shuffled<Element>(_ elements: [Element]) -> [Element] {
        var copy = elements
        shuffle(&copy)
        return copy
    }

    /// One element chosen uniformly, or `nil` when `elements` is empty.
    public mutating func element<Element>(of elements: [Element]) -> Element? {
        guard !elements.isEmpty else { return nil }
        return elements[nextInt(below: elements.count)]
    }
}
