import SwiftUI
@preconcurrency import Vision

struct SkeletonOverlayView: View {
    let points: [VNHumanBodyPoseObservation.JointName: CGPoint]

    // Define skeleton connections
    private let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.nose, .neck),
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .leftHip), (.neck, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.leftHip, .rightHip)
    ]

    var body: some View {
        Canvas { context, size in
            // Draw connections
            for (from, to) in connections {
                guard let p1 = points[from], let p2 = points[to] else { continue }
                let screenP1 = CGPoint(x: p1.x * size.width, y: p1.y * size.height)
                let screenP2 = CGPoint(x: p2.x * size.width, y: p2.y * size.height)

                var path = Path()
                path.move(to: screenP1)
                path.addLine(to: screenP2)

                context.stroke(path, with: .color(.cyan), lineWidth: 3)
            }

            // Draw joint points
            for (_, point) in points {
                let screenPoint = CGPoint(x: point.x * size.width, y: point.y * size.height)
                let rect = CGRect(x: screenPoint.x - 5, y: screenPoint.y - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: rect), with: .color(.yellow))
            }
        }
    }
}
