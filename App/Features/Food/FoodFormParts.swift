import SwiftUI
import UIKit

// The parts the two food sheets ("Twoje cele dzienne", "nowy produkt") are built from: one calm
// scrolling page, rows with a large number field, a large text field, and the note that shows
// while a change can't be saved yet. Both sheets save themselves when she closes them.

/// How wide the number fields of the food sheets are at the default text size; they grow with it.
nonisolated enum FoodFieldSize {
    static let width: CGFloat = 156
}

/// A sheet page: the usual margins, cards 16 pt apart, the night colour behind it and the grabber
/// on top. A swipe down closes it, and closing saves – there are no buttons to save or cancel.
struct FoodSheetPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                content
            }
            .padding(.horizontal, Spacing.card)
            .padding(.top, Spacing.section)
            .padding(.bottom, Spacing.section)
        }
        .scrollIndicators(.hidden)
        // Dragging down into the keyboard puts it away; the fields keep what she typed.
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.background)
    }
}

/// A row with a label on the left and a large number field on the right: "wzrost [ 168 cm ]".
/// A tap anywhere on the row puts the cursor in the field.
struct FoodNumberRow: View {
    private let label: String
    @Binding private var text: String
    private let placeholder: String
    private let unit: String?
    private let keyboard: UIKeyboardType
    @FocusState private var isFocused: Bool
    @ScaledMetric(relativeTo: .title3) private var fieldWidth: CGFloat = FoodFieldSize.width

    init(_ label: String, text: Binding<String>, placeholder: String = "", unit: String? = nil,
         keyboard: UIKeyboardType = .decimalPad) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.unit = unit
        self.keyboard = keyboard
    }

    var body: some View {
        HStack(spacing: Spacing.item) {
            Text(label)
                .rowTitle()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                // The field says it itself.
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.hairline) {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(Palette.text)
                    .focused($isFocused)
                    .accessibilityLabel(Text(spokenLabel))
                if let unit {
                    Text(unit)
                        .rowDetail()
                        .accessibilityHidden(true)
                }
            }
            .fieldBox()
            .frame(width: fieldWidth)
        }
        .frame(minHeight: TapSize.large)
        .contentShape(Rectangle())
        // Simultaneous, so a tap right on the field still places the cursor as usual.
        .simultaneousGesture(TapGesture().onEnded {
            isFocused = true
        })
    }

    /// "wzrost, cm" for VoiceOver.
    private var spokenLabel: String {
        guard let unit else { return label }
        return "\(label), \(unit)"
    }
}

/// A large text field with its label above it: "nazwa".
struct FoodTextField: View {
    private let label: String
    @Binding private var text: String
    private let placeholder: String
    @FocusState private var isFocused: Bool

    init(_ label: String, text: Binding<String>, placeholder: String = "") {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Palette.text2)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .font(.body)
                .foregroundStyle(Palette.text)
                .textInputAutocapitalization(.never)
                .focused($isFocused)
                .accessibilityLabel(Text(label))
                .fieldBox()
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    isFocused = true
                })
        }
    }
}

/// At the top of a sheet while something she changed can't be saved yet – a swipe down then
/// doesn't close it. It says so, and offers the one way out that leaves her saved data as it was.
struct FoodUnsavedNote: View {
    let onDiscard: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                message
                discardButton
            }
            VStack(alignment: .leading, spacing: Spacing.hairline) {
                message
                discardButton
            }
        }
        .transition(.opacity)
    }

    private var message: some View {
        Text(polish: "tego jeszcze nie zapiszę")
            .font(.footnote)
            .foregroundStyle(Palette.text2)
    }

    private var discardButton: some View {
        Button("zamknij bez zmian", action: onDiscard)
            .buttonStyle(LinkButtonStyle(font: .footnote.weight(.medium)))
    }
}
