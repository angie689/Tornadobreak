import XCTest
@testable import TornadoCore

final class VortexAnimationTests: XCTestCase {
    func testFrameRateIndependentPhase() {
        var sixty = VortexAnimation()
        var thirty = VortexAnimation()
        for _ in 0..<120 { sixty.advance(delta: 1.0 / 60, energy: 50) }
        for _ in 0..<60 { thirty.advance(delta: 1.0 / 30, energy: 50) }
        XCTAssertEqual(sixty.phase, thirty.phase, accuracy: 1e-10)
    }

    func testEveryFrameAndSeamHaveContinuousCounterclockwiseMotion() {
        var animation = VortexAnimation()
        var frames: Set<Int> = []
        let turn = 2 * Double.pi
        let expectedStep = turn * 0.45 / 60
        var previous = 0.0
        for _ in 0..<600 {
            animation.advance(delta: 1.0 / 60, energy: 0)
            frames.insert(animation.frameIndex)
            let angle = Double(animation.frameIndex) * turn / 24 + animation.residualAngle
            let step = (angle - previous + turn).truncatingRemainder(dividingBy: turn)
            XCTAssertEqual(step, expectedStep, accuracy: 1e-10)
            XCTAssertGreaterThanOrEqual(animation.residualAngle, 0)
            XCTAssertLessThan(animation.residualAngle, turn / 24 + 1e-10)
            previous = angle
        }
        XCTAssertEqual(frames.count, 24)
    }

    func testIntensityAndInvalidTime() {
        var weak = VortexAnimation()
        var strong = VortexAnimation()
        weak.advance(delta: 0.1, energy: 0)
        strong.advance(delta: 0.1, energy: 100)
        XCTAssertGreaterThan(strong.phase, weak.phase)
        let phase = strong.phase
        for delta in [0, -1, Double.nan, Double.infinity] {
            strong.advance(delta: delta, energy: 100)
        }
        XCTAssertEqual(strong.phase, phase)
    }
}
