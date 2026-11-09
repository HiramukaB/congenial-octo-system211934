import SwiftUI

extension View {
    /// Swipe left to reveal a bin; tapping the bin deletes. Vertical scrolling keeps working.
    func swipeToDelete(label: String = "usuń", perform delete: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(label: label, delete: delete))
    }
}

/// Her wish from the web version: rows are removed by swiping left, not by extra buttons.
struct SwipeToDelete: ViewModifier {
    let label: String
    let delete: () -> Void
    @State private var offset: CGFloat = 0
    @State private var isOpen = false
    @State private var deletions = 0

    private let revealWidth: CGFloat = 64

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            Button {
                deletions += 1
                withAnimation(.snappy) {
                    offset = 0
                    isOpen = false
                }
                delete()
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(Palette.text)
                    .frame(width: revealWidth)
                    .frame(maxHeight: .infinity)
                    .background(Palette.red.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(offset < -6 ? 1 : 0)
            .accessibilityHidden(true)

            content
                .background(Palette.card.opacity(0.001))
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 14)
                        .onChanged { value in
                            // Only horizontal drags move the row; vertical ones belong to the scroll view.
                            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                            let start: CGFloat = isOpen ? -revealWidth : 0
                            offset = min(0, max(-revealWidth * 1.5, start + value.translation.width))
                        }
                        .onEnded { value in
                            let start: CGFloat = isOpen ? -revealWidth : 0
                            let horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.5
                            let end = horizontal ? start + value.translation.width : start
                            withAnimation(.snappy) {
                                isOpen = end < -revealWidth / 2
                                offset = isOpen ? -revealWidth : 0
                            }
                        }
                )
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: deletions)
        .accessibilityAction(named: Text(label)) {
            delete()
        }
    }
}
