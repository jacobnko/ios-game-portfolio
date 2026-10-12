// Pins SeededGenerator's outputs so seeded content cannot drift between releases.

import Testing
@testable import CoreKitRandom

// MARK: - The core matches the published algorithm

/// Reference outputs of SplitMix64 for seed 1234567, as published with the
/// algorithm's reference implementation. If this fails, the core is wrong —
/// not the expectation.
@Test func coreMatchesTheSplitMix64ReferenceVector() {
    var rng = SeededGenerator(seed: 1_234_567)
    let expected: [UInt64] = [
        6_457_827_717_110_365_317,
        3_203_168_211_198_807_973,
        9_817_491_932_198_370_423,
        4_593_380_528_125_082_431,
        16_408_922_859_458_223_821,
    ]
    #expect((0..<5).map { _ in rng.next() } == expected)
}

@Test func coreMatchesTheReferenceForSeedZero() {
    var rng = SeededGenerator(seed: 0)
    #expect(rng.next() == 0xE220_A839_7B1D_CDAF)
}

// MARK: - Determinism

@Test func sameSeedGivesTheSameSequence() {
    var a = SeededGenerator(seed: 42)
    var b = SeededGenerator(seed: 42)
    for _ in 0..<1_000 {
        #expect(a.next() == b.next())
    }
}

@Test func differentSeedsDiverge() {
    var a = SeededGenerator(seed: 1)
    var b = SeededGenerator(seed: 2)
    #expect((0..<8).map { _ in a.next() } != (0..<8).map { _ in b.next() })
}

@Test func streamsAreStableAndIndependent() {
    var board1 = SeededGenerator(seed: 38, stream: "board")
    var board2 = SeededGenerator(seed: 38, stream: "board")
    var deck = SeededGenerator(seed: 38, stream: "deck")
    let a = (0..<8).map { _ in board1.next() }
    #expect(a == (0..<8).map { _ in board2.next() })
    #expect(a != (0..<8).map { _ in deck.next() })
}

@Test func adjacentSeedsOnTheSameStreamDoNotStartAlike() {
    var a = SeededGenerator(seed: 38, stream: "board")
    var b = SeededGenerator(seed: 39, stream: "board")
    // A weak mix would leave the first outputs sharing most of their high bits.
    let differingBits = (a.next() ^ b.next()).nonzeroBitCount
    #expect(differingBits > 16)
}

// MARK: - Bounded integers

@Test func nextIntStaysInsideItsBound() {
    var rng = SeededGenerator(seed: 7)
    for bound in [1, 2, 3, 6, 7, 10, 36, 1_000] {
        for _ in 0..<500 {
            let value = rng.nextInt(below: bound)
            #expect(value >= 0 && value < bound)
        }
    }
}

@Test func nextIntBelowOneIsAlwaysZero() {
    var rng = SeededGenerator(seed: 7)
    #expect((0..<20).allSatisfy { _ in rng.nextInt(below: 1) == 0 })
}

@Test func nextIntInClosedRangeHitsBothEnds() {
    var rng = SeededGenerator(seed: 11)
    let values = (0..<2_000).map { _ in rng.nextInt(in: 1...9) }
    #expect(values.min() == 1)
    #expect(values.max() == 9)
    #expect(Set(values).count == 9)
}

@Test func nextIntIsRoughlyUniform() {
    var rng = SeededGenerator(seed: 2026)
    var counts = [Int](repeating: 0, count: 6)
    let draws = 60_000
    for _ in 0..<draws { counts[rng.nextInt(below: 6)] += 1 }
    // Expected 10,000 each; a biased or broken reduction drifts far past 3%.
    #expect(counts.allSatisfy { abs($0 - draws / 6) < 300 })
}

// MARK: - Doubles

@Test func nextDoubleStaysInTheUnitInterval() {
    var rng = SeededGenerator(seed: 5)
    for _ in 0..<5_000 {
        let value = rng.nextDouble()
        #expect(value >= 0 && value < 1)
    }
}

@Test func nextDoubleInRangeRespectsBounds() {
    var rng = SeededGenerator(seed: 5)
    for _ in 0..<1_000 {
        let value = rng.nextDouble(in: 0.55...0.78)
        #expect(value >= 0.55 && value <= 0.78)
    }
}

// MARK: - Shuffling

@Test func shuffleIsAPermutation() {
    var rng = SeededGenerator(seed: 99)
    let original = Array(0..<36)
    let result = rng.shuffled(original)
    #expect(result.sorted() == original)
    #expect(result != original)
}

@Test func shuffleOfTinyArraysIsSafe() {
    var rng = SeededGenerator(seed: 99)
    var empty: [Int] = []
    var single = [1]
    rng.shuffle(&empty)
    rng.shuffle(&single)
    #expect(empty.isEmpty)
    #expect(single == [1])
}

@Test func elementOfEmptyIsNil() {
    var rng = SeededGenerator(seed: 1)
    #expect(rng.element(of: [Int]()) == nil)
    #expect(rng.element(of: [4]) == 4)
}

// MARK: - Golden values
//
// These freeze the derived operations (bounded ints, doubles, shuffle, streams).
// They were captured from this implementation once; the core underneath is
// checked against the published reference above. A change here means every
// seeded stage in every shipped game would change — treat a failure as a
// breaking change, never as a value to update.

@Test func goldenBoundedInts() {
    var rng = SeededGenerator(seed: 38)
    #expect((0..<10).map { _ in rng.nextInt(below: 6) } == GoldenValues.boundedInts)
}

@Test func goldenShuffle() {
    var rng = SeededGenerator(seed: 38)
    #expect(rng.shuffled(Array(0..<10)) == GoldenValues.shuffle)
}

@Test func goldenStream() {
    var rng = SeededGenerator(seed: 38, stream: "deck")
    #expect(rng.next() == GoldenValues.streamFirst)
}

@Test func goldenDouble() {
    var rng = SeededGenerator(seed: 38)
    #expect(rng.nextDouble() == GoldenValues.firstDouble)
}

enum GoldenValues {
    static let boundedInts: [Int] = [5, 0, 0, 1, 1, 5, 1, 4, 2, 0]
    static let shuffle: [Int] = [3, 7, 2, 5, 4, 6, 1, 8, 0, 9]
    static let streamFirst: UInt64 = 15_222_815_352_988_182_786
    static let firstDouble: Double = 0.9179963877165437
}
