import SwiftUI

extension View {
    /// Swipe left to reveal a bin; tapping the bin deletes. Vertical scrolling keeps working.
    ///
    /// A tap on the row (outside its own buttons) calls `onTap` – her "tap to edit" – or, while the
    /// bin is showing, only closes the row. With `onTap`, VoiceOver also offers "popraw".
    func swipeToDelete(label: String = "usuń", onTap: (() -> Void)? = nil,
                       perform delete: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(label: label, onTap: onTap, delete: delete))
    }
}

/// Her wish from the web version: rows are removed by swiping left, not by extra buttons,
/// and a tap on a row opens it for editing.
///
/// The swipe is a `SidewaysDrag`: a drag up or down that starts on the row scrolls the page and
/// leaves the row alone. While the row is closed only a swipe to the left opens it, so a swipe
/// to the right stays free for the way back to the screen before.
struct SwipeToDelete: ViewModifier {
    let label: String
    let onTap: (() -> Void)?
    let delete: () -> Void

    @State private var isOpen = false
    /// The live sideways drag; back to zero when the finger lifts or the drag is cancelled.
    @State private var dragWidth: CGFloat = 0
    @State private var deletions = 0

    private let revealWidth: CGFloat = 64

    func body(content: Content) -> some View {
        withEditAction(
            content
                // At least 44 pt tall, so both the row and its bin are comfortable to tap.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .offset(x: offset)
                // The swipe first, so the row follows the finger at once; a tap is what is left
                // when it doesn't move.
                .gesture(SidewaysDrag(direction: isOpen ? .either : .leftOnly,
                                      onChanged: { _, translation in
                                          dragWidth = translation.width
                                      },
                                      onEnded: { translation, velocity in
                                          settle(translation.width, velocity: velocity.width)
                                      }))
                .onTapGesture {
                    tap()
                }
                // A background gets the row's full height and doesn't move with the row.
                .background(alignment: .trailing) {
                    bin(width: -offset)
                }
                // The moved row stays inside its own bounds instead of sliding over the card's edge.
                .clipped()
                .sensoryFeedback(.impact(weight: .medium), trigger: deletions)
                .accessibilityAction(named: Text(label)) {
                    delete()
                }
        )
    }

    /// With `onTap`, VoiceOver offers "popraw" too.
    @ViewBuilder
    private func withEditAction<Row: View>(_ row: Row) -> some View {
        if let onTap {
            row.accessibilityAction(named: Text("popraw")) {
                onTap()
            }
        } else {
            row
        }
    }

    /// How far the row is moved: open or closed, plus the drag in progress.
    private var offset: CGFloat {
        let start: CGFloat = isOpen ? -revealWidth : 0
        return min(0, max(-revealWidth * 1.5, start + dragWidth))
    }

    /// The finger lifted: the row opens when it was pulled – or flicked – past half the bin, and
    /// closes otherwise.
    private func settle(_ width: CGFloat, velocity: CGFloat) {
        let start: CGFloat = isOpen ? -revealWidth : 0
        let flick = velocity.isFinite ? velocity * 0.1 : 0
        withAnimation(.snappy) {
            isOpen = start + width + flick < -revealWidth / 2
            dragWidth = 0
        }
    }

    /// The bin: as wide as the row has moved (so it never shows through the row), the row's full
    /// height, and at least 44 × 64 pt once the row is open.
    private func bin(width: CGFloat) -> some View {
        Button {
            performDelete()
        } label: {
            Image(systemName: "trash")
                .font(.body)
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Warm and quiet: removing is a choice she makes, not an alarm.
                .background(Palette.removeBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: max(0, width))
        .frame(maxHeight: .infinity)
        .clipped()
        .opacity(width > 6 ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func tap() {
        if isOpen {
            withAnimation(.snappy) {
                isOpen = false
            }
        } else {
            onTap?()
        }
    }

    private func performDelete() {
        deletions += 1
        withAnimation(.snappy) {
            isOpen = false
        }
        delete()
    }
}
