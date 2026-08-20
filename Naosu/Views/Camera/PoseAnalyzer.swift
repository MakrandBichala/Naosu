@preconcurrency import Vision
import Foundation

struct PoseAnalyzer {
    let exercise: JourneyExercise
    let observation: VNHumanBodyPoseObservation

    private enum FeedbackKind: Hashable {
        case neutral
        case goodDepth
        case badForm
        case outOfFrame
    }

    // MARK: - Tunables

    /// Ignore very low-confidence joints (Vision jitter drops below this often).
    private static let minJointConfidence: Float = 0.42
    private static let minVertexConfidence: Float = 0.48

    /// Frames required before we trust “deep” / “top” of rep (reduces one-frame spikes).
    private static let framesToConfirmActive = 4
    private static let framesToConfirmReturn = 5

    /// How many recent instant feedback votes participate in majority smoothing.
    private static let feedbackVoteWindow = 6
    /// Minimum votes for a category to “win” (must be majority of window when full).
    private static let feedbackMajorityMin = 4

    // MARK: - Static state (per session; reset via `resetRepState()`)

    private static var angleRing: [Double] = []
    private static let maxAngleSamples = 21

    private static var isInActivePosition = false
    private static var repCooldown = false

    private static var activeStreak = 0
    private static var returnStreak = 0

    /// Majority-vote buffer for form feedback (reduces banner flicker).
    private static var feedbackKindVotes: [FeedbackKind] = []

    // Universal fallback path
    private static var anchorY: CGFloat?
    private static var isDown = false
    private static var yHistory: [CGFloat] = []
    private static let maxYHistory = 11

    /// Shoulder vertical motion when there is no `poseInstruction` (universal feedback).
    private static var universalShoulderMidY: [CGFloat] = []
    private static let maxUniversalShoulderSamples = 15

    static func resetRepState() {
        isInActivePosition = false
        repCooldown = false
        angleRing.removeAll()
        activeStreak = 0
        returnStreak = 0
        feedbackKindVotes.removeAll()
        anchorY = nil
        isDown = false
        yHistory.removeAll()
        universalShoulderMidY.removeAll()
    }

    // MARK: - Key Points Extraction

    func extractKeyPoints() -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        for joint in jointNames {
            guard let point = try? observation.recognizedPoint(joint),
                  point.confidence > Self.minJointConfidence else { continue }
            points[joint] = CGPoint(x: point.location.x, y: 1 - point.location.y)
        }

        return points
    }

    // MARK: - Per-frame ingest (call once from `processPose` before feedback + reps)

    /// Samples the primary joint angle **once** for this frame so feedback and rep logic stay in sync.
    func commitPrimaryAngleSampleForCurrentFrame() {
        guard let instruction = exercise.poseInstruction,
              let raw = getPrimaryAngle(instruction: instruction) else { return }
        Self.angleRing.append(raw)
        if Self.angleRing.count > Self.maxAngleSamples {
            Self.angleRing.removeFirst()
        }
    }

    // MARK: - Feedback (median-smoothed + majority vote)

    func analyzeFeedback() -> FormFeedback {
        let instant: FeedbackKind
        if exercise.poseInstruction != nil {
            instant = instantFeedbackKindWithInstruction()
        } else {
            instant = instantFeedbackKindUniversal()
        }

        Self.feedbackKindVotes.append(instant)
        if Self.feedbackKindVotes.count > Self.feedbackVoteWindow {
            Self.feedbackKindVotes.removeFirst()
        }

        let kind = majorityFeedbackKind() ?? instant
        return mapKindToFormFeedback(kind)
    }

    private func instantFeedbackKindWithInstruction() -> FeedbackKind {
        guard let instruction = exercise.poseInstruction else { return .neutral }

        let detectedPoints = extractKeyPoints()
        if detectedPoints.isEmpty { return .neutral }

        guard let angle = medianJointAngle() else {
            return .outOfFrame
        }

        let minAngle = min(instruction.startAngle, instruction.endAngle)
        let maxAngle = max(instruction.startAngle, instruction.endAngle)
        // Slightly generous outer bound so small noise doesn’t read as “wrong” every frame.
        let validRange = (minAngle - 18)...(maxAngle + 18)

        if !validRange.contains(angle) {
            return .badForm
        }

        let depth = abs(angle - instruction.startAngle)
        if depth > instruction.repThreshold * 0.35 {
            return .goodDepth
        }

        return .neutral
    }

    private func instantFeedbackKindUniversal() -> FeedbackKind {
        let points = extractKeyPoints()
        if points.isEmpty { return .neutral }

        let hasBody =
            points[.leftShoulder] != nil ||
            points[.rightShoulder] != nil ||
            points[.leftHip] != nil ||
            points[.rightHip] != nil

        if !hasBody { return .outOfFrame }

        // Track shoulder-line height so “good” reflects visible movement, not pose ring noise.
        if let ls = points[.leftShoulder], let rs = points[.rightShoulder] {
            let mid = (ls.y + rs.y) / 2
            Self.universalShoulderMidY.append(mid)
            if Self.universalShoulderMidY.count > Self.maxUniversalShoulderSamples {
                Self.universalShoulderMidY.removeFirst()
            }
        }
        if Self.universalShoulderMidY.count >= 6 {
            let sorted = Self.universalShoulderMidY.sorted()
            let range = (sorted.last ?? 0) - (sorted.first ?? 0)
            if range > 0.028 { return .goodDepth }
        }
        return .neutral
    }

    private func majorityFeedbackKind() -> FeedbackKind? {
        let votes = Self.feedbackKindVotes
        guard votes.count >= Self.feedbackMajorityMin else { return nil }

        var counts: [FeedbackKind: Int] = [:]
        for v in votes { counts[v, default: 0] += 1 }
        guard let best = counts.max(by: { $0.value < $1.value }) else { return nil }
        return best.value >= Self.feedbackMajorityMin ? best.key : nil
    }

    private func mapKindToFormFeedback(_ kind: FeedbackKind) -> FormFeedback {
        switch kind {
        case .goodDepth:
            return .good
        case .badForm:
            let cue = exercise.poseInstruction?.formCues.first ?? "alignment"
            return .adjust(cue)
        case .outOfFrame:
            return .adjust("position — make sure full body is visible")
        case .neutral:
            return .none
        }
    }

    // MARK: - Rep counting (median angle + streaks)

    func checkRepCompletion(currentCount: Int) -> Bool {
        guard let instruction = exercise.poseInstruction else {
            return universalRepCheck()
        }

        guard let angle = medianJointAngle() else {
            Self.activeStreak = 0
            Self.returnStreak = 0
            return false
        }

        guard !Self.repCooldown else { return false }

        let threshold = max(instruction.repThreshold, 8)
        let startAngle = instruction.startAngle
        let decreasing = instruction.repDirection.normalized == "decrease"

        let movedToActive = decreasing
            ? angle < startAngle - threshold
            : angle > startAngle + threshold

        let returnedToStart = decreasing
            ? angle > startAngle - (threshold * 0.35)
            : angle < startAngle + (threshold * 0.35)

        if movedToActive {
            Self.activeStreak += 1
            Self.returnStreak = 0
        } else if returnedToStart {
            Self.returnStreak += 1
            Self.activeStreak = 0
        } else {
            // In between — decay streaks slowly so brief hesitation doesn’t reset everything.
            Self.activeStreak = max(0, Self.activeStreak - 1)
            Self.returnStreak = max(0, Self.returnStreak - 1)
        }

        if !Self.isInActivePosition {
            if Self.activeStreak >= Self.framesToConfirmActive {
                Self.isInActivePosition = true
                Self.returnStreak = 0
            }
            return false
        }

        // In active phase: look for a controlled return to start.
        if Self.returnStreak >= Self.framesToConfirmReturn {
            Self.isInActivePosition = false
            Self.activeStreak = 0
            Self.returnStreak = 0
            Self.repCooldown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                Self.repCooldown = false
            }
            return true
        }

        return false
    }

    // MARK: - Smoothing (single ring, committed once per frame)

    private func medianJointAngle() -> Double? {
        guard Self.angleRing.count >= 1 else { return nil }
        let slice = Array(Self.angleRing.suffix(9))
        let sorted = slice.sorted()
        return sorted[sorted.count / 2]
    }

    // MARK: - Angle computation

    private func getPrimaryAngle(instruction: PoseInstruction) -> Double? {
        guard instruction.primaryJoints.count >= 3 else { return nil }

        func jointName(_ str: String) -> VNHumanBodyPoseObservation.JointName? {
            switch str {
            case "leftKnee": return .leftKnee
            case "rightKnee": return .rightKnee
            case "leftHip": return .leftHip
            case "rightHip": return .rightHip
            case "leftShoulder": return .leftShoulder
            case "rightShoulder": return .rightShoulder
            case "leftElbow": return .leftElbow
            case "rightElbow": return .rightElbow
            case "leftWrist": return .leftWrist
            case "rightWrist": return .rightWrist
            case "leftAnkle": return .leftAnkle
            case "rightAnkle": return .rightAnkle
            case "nose": return .nose
            case "neck": return .neck
            default: return nil
            }
        }

        guard let j1 = jointName(instruction.primaryJoints[0]),
              let j2 = jointName(instruction.primaryJoints[1]),
              let j3 = jointName(instruction.primaryJoints[2])
        else { return nil }

        return getAngle(joint1: j1, joint2: j2, joint3: j3)
    }

    /// Angle (in degrees) at `joint2`, the vertex of the triangle j1–j2–j3.
    private func getAngle(
        joint1: VNHumanBodyPoseObservation.JointName,
        joint2: VNHumanBodyPoseObservation.JointName,
        joint3: VNHumanBodyPoseObservation.JointName
    ) -> Double? {
        guard let p1 = try? observation.recognizedPoint(joint1),
              let p2 = try? observation.recognizedPoint(joint2),
              let p3 = try? observation.recognizedPoint(joint3),
              p1.confidence > Self.minJointConfidence,
              p2.confidence > Self.minVertexConfidence,
              p3.confidence > Self.minJointConfidence else {
            return nil
        }
        let v1x = p1.location.x - p2.location.x
        let v1y = p1.location.y - p2.location.y
        let v2x = p3.location.x - p2.location.x
        let v2y = p3.location.y - p2.location.y
        let dot = v1x * v2x + v1y * v2y
        let mag1 = sqrt(v1x * v1x + v1y * v1y)
        let mag2 = sqrt(v2x * v2x + v2y * v2y)
        guard mag1 > 1e-4, mag2 > 1e-4 else { return nil }
        let cosTheta = max(-1.0, min(1.0, dot / (mag1 * mag2)))
        return acos(cosTheta) * 180.0 / .pi
    }

    // MARK: - Universal fallbacks (when poseInstruction is nil)

    func universalFeedback() -> FormFeedback {
        analyzeFeedback()
    }

    func universalRepCheck() -> Bool {
        let name = exercise.name.lowercased()
        let isUpperBody =
            name.contains("curl") ||
            name.contains("press") || name.contains("raise") ||
            name.contains("row") || name.contains("push") ||
            name.contains("pull") || name.contains("swing")

        if isUpperBody {
            return trackJointMovement(
                joint1: .leftWrist, joint2: .rightWrist,
                threshold: 0.055)
        } else {
            return trackJointMovement(
                joint1: .leftHip, joint2: .rightHip,
                threshold: 0.065)
        }
    }

    private func trackJointMovement(
        joint1: VNHumanBodyPoseObservation.JointName,
        joint2: VNHumanBodyPoseObservation.JointName,
        threshold: CGFloat
    ) -> Bool {
        var ys: [CGFloat] = []
        for j in [joint1, joint2] {
            if let pt = try? observation.recognizedPoint(j), pt.confidence > Self.minJointConfidence {
                ys.append(1 - pt.location.y)
            }
        }
        guard !ys.isEmpty else { return false }
        let y = ys.reduce(0, +) / CGFloat(ys.count)

        Self.yHistory.append(y)
        if Self.yHistory.count > Self.maxYHistory { Self.yHistory.removeFirst() }
        let smoothY: CGFloat
        if Self.yHistory.count >= 3 {
            let s = Self.yHistory.sorted()
            smoothY = s[s.count / 2]
        } else {
            smoothY = y
        }

        guard let anchor = Self.anchorY else {
            Self.anchorY = smoothY
            return false
        }

        if !Self.isDown {
            if smoothY - anchor > threshold {
                Self.isDown = true
            } else if anchor - smoothY > threshold * 0.2 {
                Self.anchorY = smoothY
            }
        } else {
            if anchor - smoothY > threshold * 0.35 {
                Self.isDown = false
                Self.anchorY = smoothY
                return true
            }
        }
        return false
    }
}

// MARK: - String normalization

private extension String {
    var normalized: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
