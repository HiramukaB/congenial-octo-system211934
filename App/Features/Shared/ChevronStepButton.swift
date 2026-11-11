import SwiftUI

/// A round 44 pt button with a chevron, for stepping through days and months ("poprzedni dzień",
/// "następny miesiąc"). Quiet next to the content it changes; a light tick on every step.
/// A step that isn't possible (the day after today) stays in place, faded.
struct ChevronStepButton: View {
    let systemImage: String
    let label: String
    var isEnabled = true
    let action: () -> Void
    @State private var steps = 0

    var body: some View {
        Button {
            steps += 1
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: TapSize.minimum, height: TapSize.minimum)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(TilePressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .accessibilityLabel(Text(label))
        .sensoryFeedback(.selection, trigger: steps)
    }
}
