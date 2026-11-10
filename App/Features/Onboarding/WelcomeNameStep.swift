import SwiftUI
import UIKit
import AboutHerCore

/// "jak mam do Ciebie mówić?": the name the app greets her with. It saves itself as she types;
/// left empty, no name is kept and the app greets her without one.
struct WelcomeNameStep: View {
    @Environment(AppStore.self) private var store
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var name = ""
    @State private var hasLoaded = false
    @FocusState private var isFocused: Bool

    var body: some View {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        WelcomePage(step: .name,
                    title: "jak mam do Ciebie mówić?",
                    subtitle: "imię albo zdrobnienie – tak będę Cię witać",
                    canSkip: trimmed.isEmpty,
                    onBack: onBack,
                    onNext: onNext) {
            VStack(alignment: .leading, spacing: Spacing.item) {
                TextField("Twoje imię", text: $name)
                    .displayFont(24, relativeTo: .title2)
                    .foregroundStyle(Palette.text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textContentType(.givenName)
                    .submitLabel(.next)
                    .focused($isFocused)
                    .onSubmit(onNext)
                    .fieldBox()
                    .accessibilityLabel(Text("imię"))
                if !trimmed.isEmpty {
                    ConfirmationNote(text: "miło mi, \(trimmed)")
                }
            }
            .animation(.smooth(duration: 0.25), value: trimmed.isEmpty)
        }
        .onAppear(perform: load)
        .onChange(of: name) { _, newValue in
            _ = store.setPreferredName(newValue)
        }
    }

    /// What she gave before (also on a later launch); the keyboard only while there is no name yet.
    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        name = store.preferredName ?? ""
        if name.isEmpty {
            isFocused = true
        }
    }
}
