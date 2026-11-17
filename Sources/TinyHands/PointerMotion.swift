import CoreGraphics
import Foundation

/// How the pointer reacts to being moved. Pure state and arithmetic, no layers, so the
/// same code drives the overlay and can be simulated on its own.
///
/// The toy is a rigid hand on a rigid rod with its fingertip planted on the glass under
/// the cursor. Dragging it sideways does two things, both pivoting on the fingertip so the
/// tip never leaves the cursor:
///
/// - **Roll.** The hand turns about its own long axis toward the way it is being moved,
///   as if its weight hung below that axis like a keel and the drag of the move tipped it
///   over. This is shown with the pre-drawn roll frames.
/// - **Swing.** The far end of the rod trails behind, so the whole pointer leans back
///   against the motion.
///
/// Each is a pendulum in thick air: a damped spring (the spring is gravity) pushed by a
/// drag that grows with sideways speed, plus a kick whenever that push changes (inertia),
/// which is what makes it answer a quick move straight away. Hold a steady drag and it
/// stays tipped; stop, and it falls back through upright, past it, and settles.
struct PointerMotion {
    struct Tuning {
        /// Roll frames are drawn every 11 degrees, four each way.
        var rollStepDegrees = 11.0
        var rollSteps = 4
        /// Degrees of roll per pt/s of sideways speed, before it saturates. At 0.03 a
        /// 700 pt/s drag holds the second drawing and only a real flick reaches the last.
        var rollGain = 0.03
        /// Spring stiffness as a natural frequency (rad/s) and damping ratio.
        var rollFrequency = 20.0
        var rollDamping = 0.40
        /// The inertia kick, in seconds: how far ahead of the spring a change in the push
        /// throws the hand. It is applied to the spring's rate, after the push has been
        /// limited, so it does not care how often the mouse reports.
        var rollLead = 0.06
        /// The rod's lean, in degrees: soft limit, gain per pt/s, spring, inertia kick.
        var swingLimit = 11.0
        var swingGain = 0.011
        var swingFrequency = 14.0
        var swingDamping = 0.45
        var swingLead = 0.035
        /// Time constant (s) of the speed estimate; it keeps single-frame jitter out.
        var smoothing = 0.02
        /// Below this sideways speed (pt/s) the hand does not react at all, so careful
        /// pointing stays perfectly still.
        var deadband = 90.0
        /// A shown roll frame is kept until the roll is this many degrees past the halfway
        /// point to the next one, so a steady drag cannot flicker between two drawings.
        var frameHold = 2.2
        /// A tick longer than this (s) is a stall or a wake from sleep, not a move.
        var stall = 0.25
        /// A single-tick jump longer than this (pt) and faster than `warpSpeed` (pt/s) is
        /// the cursor being warped, not moved.
        var warp = 300.0
        var warpSpeed = 15000.0
    }

    var tuning = Tuning()
    /// Smoothed cursor velocity in pt/s (screen axes, y up).
    private(set) var velocity = CGVector.zero
    /// Roll in degrees. Positive carries the top of the hand toward screen right.
    private(set) var roll = 0.0
    private(set) var rollRate = 0.0
    /// Lean of the whole pointer about the fingertip, in degrees, counter-clockwise positive.
    private(set) var swing = 0.0
    private(set) var swingRate = 0.0
    /// The roll frame being shown: -rollSteps ... rollSteps.
    private(set) var rollStep = 0
    private var lastRollTarget = 0.0
    private var lastSwingTarget = 0.0

    var isAtRest: Bool {
        roll == 0 && rollRate == 0 && swing == 0 && swingRate == 0 && velocity == .zero
    }

    mutating func reset() {
        velocity = .zero
        roll = 0; rollRate = 0; swing = 0; swingRate = 0
        rollStep = 0; lastRollTarget = 0; lastSwingTarget = 0
    }

    /// Advances the motion by `dt` seconds during which the cursor moved by `moved` points.
    /// `tilt` is the hand's resting tilt in radians (counter-clockwise): the rod lies along
    /// the hand, so that sets which way is "across the rod" for the swing.
    mutating func step(moved: CGVector, dt real: Double, tilt: Double) {
        guard real > 0 else { return }
        var moved = moved
        if real > tuning.stall {
            // The timer stalled or the Mac slept: drop whatever happened meanwhile.
            velocity = .zero
            lastRollTarget = 0; lastSwingTarget = 0
            return
        }
        let distance = hypot(Double(moved.dx), Double(moved.dy))
        if distance > tuning.warp && distance / real > tuning.warpSpeed { moved = .zero }
        // Speed comes from the real elapsed time; the springs take at most 50 ms per tick.
        let raw = CGVector(dx: moved.dx / real, dy: moved.dy / real)
        let dt = min(real, 0.05)
        let blend = 1 - exp(-real / tuning.smoothing)
        velocity.dx += (raw.dx - velocity.dx) * blend
        velocity.dy += (raw.dy - velocity.dy) * blend

        func pastDeadband(_ v: Double) -> Double {
            abs(v) <= tuning.deadband ? 0 : v - tuning.deadband * (v < 0 ? -1 : 1)
        }
        // The roll answers screen-sideways travel, whatever the hand's resting tilt: move
        // right and it rolls right. The swing answers travel across the rod.
        let sideways = pastDeadband(Double(velocity.dx))
        let across = pastDeadband(Double(velocity.dx) * cos(tilt) + Double(velocity.dy) * sin(tilt))
        let rollLimit = tuning.rollStepDegrees * Double(tuning.rollSteps)
        let rollTarget = rollLimit * tanh(sideways * tuning.rollGain / rollLimit)
        // The rod's far end lags behind, so the lean is against the motion.
        let swingTarget = -tuning.swingLimit * tanh(across * tuning.swingGain / tuning.swingLimit)
        // The inertia kick: a change in the push throws the spring's rate. It is linear in
        // the change, so a mouse that reports in steps averages out to the same motion.
        rollRate += tuning.rollFrequency * tuning.rollFrequency * tuning.rollLead * (rollTarget - lastRollTarget)
        swingRate += tuning.swingFrequency * tuning.swingFrequency * tuning.swingLead * (swingTarget - lastSwingTarget)
        lastRollTarget = rollTarget
        lastSwingTarget = swingTarget

        // Small fixed sub-steps keep the springs stable at any timer rate.
        let n = max(1, Int((dt / (1.0 / 240.0)).rounded(.up)))
        let h = dt / Double(n)
        for _ in 0..<n {
            let wr = tuning.rollFrequency
            rollRate += (wr * wr * (rollTarget - roll) - 2 * tuning.rollDamping * wr * rollRate) * h
            roll += rollRate * h
            let ws = tuning.swingFrequency
            swingRate += (ws * ws * (swingTarget - swing) - 2 * tuning.swingDamping * ws * swingRate) * h
            swing += swingRate * h
        }
        // The drawings stop at the last roll frame, and the rod only leans so far.
        let hardRoll = rollLimit * 1.15
        if abs(roll) > hardRoll { roll = hardRoll * (roll < 0 ? -1 : 1); rollRate = 0 }
        let hardSwing = tuning.swingLimit * 1.3
        if abs(swing) > hardSwing { swing = hardSwing * (swing < 0 ? -1 : 1); swingRate = 0 }

        // Come to a true stop instead of creeping toward zero for ever.
        if abs(roll) < 0.3 && abs(rollRate) < 1.5 && abs(swing) < 0.04 && abs(swingRate) < 0.4
            && abs(velocity.dx) < 1 && abs(velocity.dy) < 1 && moved == .zero {
            reset()
            return
        }

        // Pick the drawing, holding the current one a little past the halfway point.
        let step = tuning.rollStepDegrees
        let limit = Double(tuning.rollSteps)
        while roll - step * Double(rollStep) > step / 2 + tuning.frameHold && Double(rollStep) < limit { rollStep += 1 }
        while step * Double(rollStep) - roll > step / 2 + tuning.frameHold && Double(rollStep) > -limit { rollStep -= 1 }
        // Coming back to rest, the hold must not strand the hand one drawing off upright.
        if abs(roll) < 2.0 && abs(rollRate) < 20 { rollStep = 0 }
    }
}
