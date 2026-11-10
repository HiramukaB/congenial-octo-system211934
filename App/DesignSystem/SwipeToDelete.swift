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
struct SwipeToDelete: ViewModifier {
    let label: String
    let onTap: (() -> Void)?
    let delete: () -> Void

    @State private var isOpen = false
    /// The live horizontal drag. It goes back to zero by itself when the drag ends or is
    /// cancelled, so a row is never left half open.
    @GestureState(resetTransaction: Transaction(animation: .snappy)) private var dragWidth: CGFloat = 0
    @State private var deletions = 0

    private let revealWidth: CGFloat = 64

    func body(content: Content) -> some View {
        withEditAction(
            content
                // At least 44 pt tall, so both the row and its bin are comfortable to tap.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .offset(x: offset)
                .onTapGesture {
                    tap()
                }
                .simultaneousGesture(drag)
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

    private var drag: some Gesture {
        DragGesture(minimumDistance: 14)
            .updating($dragWidth) { value, width, _ in
                // Only horizontal drags move the row; vertical ones belong to the scroll view.
                if abs(value.translation.width) > abs(value.translation.height) * 1.5 {
                    width = value.translation.width
                }
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                let start: CGFloat = isOpen ? -revealWidth : 0
                withAnimation(.snappy) {
                    isOpen = start + value.translation.width < -revealWidth / 2
                }
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
                .background(Palette.red.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
