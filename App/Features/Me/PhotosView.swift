import SwiftUI
import PhotosUI
import UIKit
import ImageIO
import UniformTypeIdentifiers
import AboutHerCore

/// "zdjęcia", opened from "ja": her progress photos in a clean grid by month, the newest first.
/// They come from her gallery through the system picker, which needs no access to the gallery,
/// and a smaller copy is kept only inside the app – never in her gallery, never sent anywhere.
/// A tap shows a photo large; she swipes to the ones before and after it, and can remove it there.
struct PhotosView: View {
    @Environment(AppStore.self) private var store
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isAdding = false
    @State private var isPicking = false
    /// How many of the photos she picked last couldn't be opened.
    @State private var failedCount = 0
    /// "dodałam …" for a moment after photos were added.
    @State private var addedNote: String? = nil
    @State private var additions = 0
    @State private var shownPhoto: ProgressPhoto? = nil

    var body: some View {
        let photos = store.data.photosNewestFirst
        Screen {
            ScreenHeader(title: "zdjęcia", subtitle: "tylko w tym telefonie – nie w Twojej galerii")
            if photos.isEmpty && !isAdding {
                Card {
                    EmptyState(title: "tu zbierzesz zdjęcia swojej drogi",
                               message: "jedno co jakiś czas wystarczy",
                               actionTitle: "dodaj pierwsze zdjęcie",
                               action: { isPicking = true })
                }
            } else {
                StarActionButton(isAdding ? "dodaję zdjęcia…" : "dodaj zdjęcia", isEnabled: !isAdding) {
                    isPicking = true
                }
            }
            if let addedNote {
                ConfirmationNote(text: addedNote)
            }
            if failedCount > 0 {
                Text(polish: failedCount == 1
                     ? "jednego zdjęcia nie udało mi się otworzyć – spróbuj jeszcze raz"
                     : "kilku zdjęć nie udało mi się otworzyć – spróbuj jeszcze raz")
                    .font(.footnote)
                    .foregroundStyle(Palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !photos.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.group) {
                    ForEach(PhotoMonth.group(photos)) { month in
                        monthSection(month)
                    }
                }
                .padding(.top, Spacing.tight)
                MoreInfo("gdzie są zdjęcia?",
                         text: "tylko w tej aplikacji – nie w Twojej galerii i nigdzie ich nie wysyłam. Nie ma ich w dziennych kopiach Twoich danych, więc gdy usuniesz aplikację, znikną razem z nią")
                    .padding(.top, Spacing.tight)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // The picker as a modifier: its label closure is nonisolated in the iOS 26 SDK.
        .photosPicker(isPresented: $isPicking, selection: $pickedItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            // Emptied right away, so the picker opens fresh next time.
            pickedItems = []
            let store = self.store
            Task {
                await add(items, to: store)
            }
        }
        .sheet(item: $shownPhoto) { photo in
            PhotoViewer(photo: photo)
        }
        .task(id: additions) {
            guard additions > 0 else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) {
                addedNote = nil
            }
        }
    }

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.tight), count: 3)

    /// One month: its name, then its photos three to a row.
    private func monthSection(_ month: PhotoMonth) -> some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Text(PolishDate.monthYear(month.id))
                .sectionTitle()
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Self.columns, alignment: .leading, spacing: Spacing.tight) {
                ForEach(month.photos) { photo in
                    tile(photo)
                }
            }
        }
    }

    private func tile(_ photo: ProgressPhoto) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        return Button {
            shownPhoto = photo
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    PhotoFileImage(url: store.photoURL(photo), maxPixelSize: 480, fills: true)
                }
                .clipShape(shape)
                .contentShape(shape)
        }
        .buttonStyle(TilePressStyle())
        .accessibilityLabel(Text("zdjęcie z \(PolishDate.dayMonth(photo.day))"))
    }

    /// Keeps a smaller JPEG copy of each picked photo for today. Each is converted away from the
    /// main thread, one at a time.
    private func add(_ items: [PhotosPickerItem], to store: AppStore) async {
        isAdding = true
        failedCount = 0
        var failed = 0
        var added = 0
        for item in items {
            guard let original = try? await item.loadTransferable(type: Data.self),
                  let jpeg = await Task.detached(priority: .userInitiated, operation: {
                      PhotoFiles.jpeg(from: original)
                  }).value
            else {
                failed += 1
                continue
            }
            // Refused or not written: the store tells her why, and the rest would go the same way.
            guard store.addPhoto(jpeg: jpeg, on: store.today) else { break }
            added += 1
        }
        failedCount = failed
        isAdding = false
        if added > 0 {
            withAnimation(.smooth) {
                addedNote = added == 1
                    ? "dodałam zdjęcie"
                    : "dodałam \(added) \(PolishPlural.form(added, one: "zdjęcie", few: "zdjęcia", many: "zdjęć"))"
            }
            additions += 1
        }
    }
}

/// Her photos large, one at a time, with the day as the title. A swipe sideways goes to the
/// photo before or after; removing one asks once more. Swiped down or closed, it goes away.
private struct PhotoViewer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// The photo on screen.
    @State private var currentID: UUID
    @State private var isAskingToRemove = false

    init(photo: ProgressPhoto) {
        _currentID = State(initialValue: photo.id)
    }

    var body: some View {
        let photos = store.data.photosNewestFirst
        let current = photos.first { $0.id == currentID }
        NavigationStack {
            TabView(selection: $currentID) {
                ForEach(photos) { photo in
                    PhotoPage(url: store.photoURL(photo), label: "zdjęcie z \(PolishDate.dayMonth(photo.day))")
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Palette.background)
            .navigationTitle(current.map { InnerFormat.date($0.day, today: store.today) } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isAskingToRemove = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(Text("usuń to zdjęcie"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("zamknij"))
                }
            }
            .confirmationDialog("usunąć to zdjęcie?", isPresented: $isAskingToRemove, titleVisibility: .visible) {
                Button("usuń zdjęcie") {
                    removeCurrent()
                }
                Button("zostaw", role: .cancel) {}
            } message: {
                Text(polish: "usunę je z aplikacji i nie da się go już przywrócić")
            }
        }
        .tint(Palette.accent)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// Removes the photo on screen and shows the next one. Closes when none is left – and when it
    /// couldn't be removed, so the store's note about it can show.
    private func removeCurrent() {
        let photos = store.data.photosNewestFirst
        guard let index = photos.firstIndex(where: { $0.id == currentID }) else {
            dismiss()
            return
        }
        let removedID = currentID
        var next: ProgressPhoto? = nil
        if photos.indices.contains(index + 1) {
            next = photos[index + 1]
        } else if index > 0 {
            next = photos[index - 1]
        }
        store.removePhoto(removedID)
        let isRemoved = !store.data.photos.contains { $0.id == removedID }
        if isRemoved, let next {
            currentID = next.id
        } else {
            dismiss()
        }
    }
}

/// One photo as large as it fits, or a gentle note when its file is gone.
private struct PhotoPage: View {
    let url: URL
    /// What VoiceOver says for the photo: "zdjęcie z 7 listopada".
    let label: String

    var body: some View {
        Group {
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                PhotoFileImage(url: url, maxPixelSize: 2048)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(label))
                    .accessibilityAddTraits(.isImage)
            } else {
                Text(polish: "nie mogę znaleźć tego zdjęcia w telefonie – mogło zniknąć, gdy wczytywałam kopię Twoich danych. Możesz usunąć ten wpis")
                    .bodyText()
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.card)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One of her photos read from its file away from the main thread, or a gentle placeholder while
/// it loads and when the file isn't there (e.g. after her data came back from a daily copy).
private struct PhotoFileImage: View {
    let url: URL
    let maxPixelSize: Int
    var fills = false

    @State private var loaded: PhotoImageBox? = nil
    @State private var isMissing = false

    var body: some View {
        ZStack {
            if let loaded {
                if fills {
                    Image(uiImage: loaded.image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(uiImage: loaded.image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                }
            } else {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .fill(Palette.accentBackground.opacity(0.6))
                if isMissing {
                    OrganicStar()
                        .fill(Palette.accentDim.opacity(0.7))
                        .frame(width: 18, height: 18)
                        .accessibilityHidden(true)
                } else {
                    ProgressView()
                        .tint(Palette.accentDim)
                }
            }
        }
        .task(id: url) {
            let fileURL = url
            let size = maxPixelSize
            let image = await Task.detached(priority: .userInitiated) {
                PhotoFiles.image(at: fileURL, maxPixelSize: size)
            }.value
            loaded = image
            isMissing = image == nil
        }
    }
}

/// One month of photos.
private struct PhotoMonth: Identifiable {
    /// The first day of the month.
    let id: LocalDate
    var photos: [ProgressPhoto]

    /// `photos`, the newest first, in months – the newest month first.
    static func group(_ photos: [ProgressPhoto]) -> [PhotoMonth] {
        var months: [PhotoMonth] = []
        for photo in photos {
            let month = photo.day.firstOfMonth
            if let last = months.indices.last, months[last].id == month {
                months[last].photos.append(photo)
            } else {
                months.append(PhotoMonth(id: month, photos: [photo]))
            }
        }
        return months
    }
}

/// A decoded photo handed from the background back to the screen. A UIImage is immutable and safe
/// to pass between threads.
private nonisolated final class PhotoImageBox: @unchecked Sendable {
    let image: UIImage

    init(image: UIImage) {
        self.image = image
    }
}

/// Her photos as JPEG files, read and written with ImageIO. Nothing here touches the screen, so it
/// runs away from the main thread.
private nonisolated enum PhotoFiles {
    /// The longest side of a kept photo, in pixels.
    static let keptPixelSize = 1600

    /// A JPEG of `data` – any image the picker gives: HEIC, JPEG, PNG … – upright and at most
    /// `keptPixelSize` on its longest side. None of the original's metadata is kept: no place, no
    /// device. Nil when it can't be read as an image.
    static func jpeg(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixelSize: keptPixelSize))
        else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData,
                                                                 UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.85]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// The photo at `url`, at most `maxPixelSize` on its longest side; nil when the file is missing
    /// or can't be read.
    static func image(at url: URL, maxPixelSize: Int) -> PhotoImageBox? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixelSize: maxPixelSize))
        else { return nil }
        return PhotoImageBox(image: UIImage(cgImage: image))
    }

    private static func thumbnailOptions(maxPixelSize: Int) -> CFDictionary {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Upright, whichever way the phone was held.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return options as CFDictionary
    }
}
