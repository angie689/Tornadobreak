import Foundation

/// One clock drives both the atlas and the sub-frame rotation. Atlas frames are
/// exact 15-degree counterclockwise samples, so the residual angle fills the gaps
/// without blending two translucent clouds or running competing SKActions.
public struct VortexAnimation: Sendable {
    public static let frameCount = 24
    public static let columns = 6
    public static let rows = 4
    public static let frameSize = 192
    public private(set) var phase: Double = 0

    public init() {}

    public var frameIndex: Int {
        min(Self.frameCount - 1, Int(phase / Self.frameAngle))
    }
    public var residualAngle: Double {
        phase - Double(frameIndex) * Self.frameAngle
    }
    private static let frameAngle = 2 * Double.pi / Double(frameCount)

    public mutating func advance(delta: Double, energy: Double) {
        guard delta.isFinite, delta > 0, energy.isFinite else { return }
        // Continuous intensity avoids sudden speed changes at EF boundaries.
        let intensity = min(max(energy / 100, 0), 1)
        let turnsPerSecond = 0.45 + intensity * 0.40
        phase = (phase + delta * turnsPerSecond * 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
    }
}
