import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Which way a sideways drag may start.
nonisolated enum SidewaysDirection: Sendable {
    /// Left or right: a scale.
    case either
    /// Only to the left: a row that swipes open. A drag to the right stays free for the way back.
    case leftOnly
}

/// A sideways drag for controls inside a scroll view: the scales (`DragScale`, the minutes of a
/// workout) and the rows that swipe open (`swipeToDelete`).
///
/// It is a UIKit pan that takes the touch only when her finger moves more sideways than up or
/// down. A mostly vertical drag fails it within a few points – also when it starts right on the
/// control – so the page scrolls as usual; once the finger moves sideways, the page holds still.
/// SwiftUI's own `DragGesture` can't promise that inside a `ScrollView`.
///
///     track.gesture(SidewaysDrag(onChanged: { location, _ in select(at: location.x) },
///                                onEnded: { _, _ in finish() }))
struct SidewaysDrag: UIGestureRecognizerRepresentable {
    var direction: SidewaysDirection = .either
    /// Where the finger is, in the coordinates of the view the drag is attached to, and how far it
    /// has moved since the drag began.
    var onChanged: (_ location: CGPoint, _ translation: CGSize) -> Void
    /// The finger lifted, or the drag was cancelled: how far it moved in all, and how fast at the end.
    var onEnded: (_ translation: CGSize, _ velocity: CGSize) -> Void

    func makeUIGestureRecognizer(context: Context) -> SidewaysPanRecognizer {
        let recognizer = SidewaysPanRecognizer()
        recognizer.maximumNumberOfTouches = 1
        recognizer.allowsRightward = direction == .either
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: SidewaysPanRecognizer, context: Context) {
        recognizer.allowsRightward = direction == .either
    }

    func handleUIGestureRecognizerAction(_ recognizer: SidewaysPanRecognizer, context: Context) {
        let moved = recognizer.translation(in: recognizer.view)
        let translation = CGSize(width: moved.x, height: moved.y)
        switch recognizer.state {
        case .began, .changed:
            onChanged(context.converter.localLocation, translation)
        case .ended, .cancelled:
            let speed = recognizer.velocity(in: recognizer.view)
            onEnded(translation, CGSize(width: speed.x, height: speed.y))
        default:
            break
        }
    }
}

/// The pan behind `SidewaysDrag`. It fails as soon as the finger has clearly moved more up or down
/// than sideways (or to the right, when only a start to the left is allowed). The page's scroll view
/// waits for that answer, so the two never fight over one touch.
final class SidewaysPanRecognizer: UIPanGestureRecognizer {
    /// Whether a drag that starts to the right may begin.
    var allowsRightward = true

    /// How far the finger moves before its direction counts – less than a scroll view needs to start.
    private static let decidingDistance: CGFloat = 6
    private var startPoint: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if startPoint == nil, let touch = touches.first {
            startPoint = touch.location(in: nil)
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible, let startPoint, let touch = touches.first {
            let point = touch.location(in: nil)
            let sideways = point.x - startPoint.x
            let upDown = abs(point.y - startPoint.y)
            let isUpOrDown = upDown >= Self.decidingDistance && upDown > abs(sideways)
            let isBlockedRightward = !allowsRightward && sideways >= Self.decidingDistance && sideways >= upDown
            if isUpOrDown || isBlockedRightward {
                state = .failed
                return
            }
        }
        super.touchesMoved(touches, with: event)
    }

    override func reset() {
        super.reset()
        startPoint = nil
    }

    /// The scroll view's own pan waits until this one knows the direction: up or down, the page
    /// scrolls; sideways, the control moves and the page holds still.
    override func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let scrollView = otherGestureRecognizer.view as? UIScrollView,
           otherGestureRecognizer === scrollView.panGestureRecognizer {
            return true
        }
        return super.shouldBeRequiredToFail(by: otherGestureRecognizer)
    }
}
