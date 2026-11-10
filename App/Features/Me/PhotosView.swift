import SwiftUI
import PhotosUI
import UIKit
import ImageIO
import UniformTypeIdentifiers
import AboutHerCore

/// "zdjęcia", opened from "ja": her progress photos by month, the newest first. They come from her
/// gallery through the system picker, which needs no access to the gallery, and a smaller copy is
/// kept only inside the app – never in her gallery, never sent anywhere. A tap shows a photo large,
/// where it can be removed.
struct PhotosView: View {
    @Environment(AppStore.self) private var store
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isAdding = false
    @State private var isPicking = false
    /// How many of the photos she picked last couldn't be opened.
    @State private var failedCount = 0
    @State private var shownPhoto: ProgressPhoto? = nil

    var body: some View {
        let months = PhotoMonth.group(store.data.photosNewestFirst)
        Screen {
            Text("zdjęcia").screenTitle()
            Text(polish: "lekki dziennik Twojej drogi, w Twoim tempie. Zdjęcia zostają tylko w tym telefonie, w aplikacji – nie trafiają do Twojej galerii i nigdzie ich nie wysyłam")
                .bodyText()
            addCard
            ForEach(months) { month in
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(PolishDate.monthYear(month.id)).sectionTitle()
                        LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 12) {
                            ForEach(month.photos) { photo in
                                tile(photo)
                            }
                        }
                    }
                }
            }
            Text(polish: "zdjęć nie ma w dziennych kopiach Twoich danych, więc gdy usuniesz aplikację, znikną razem z nią")
                .font(.footnote)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
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
            PhotoDetailSheet(photo: photo)
        }
    }

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var addCard: some View {
        Button {
            isPicking = true
        } label: {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        OrganicStar()
                            .fill(Palette.accent)
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("dodaj zdjęcie").sectionTitle()
                            Text(polish: "wybierz je z galerii – zapiszę tu jego kopię z dzisiejszą datą")
                                .font(.footnote)
                                .foregroundStyle(Palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        if isAdding {
                            ProgressView()
                                .tint(Palette.accentDim)
                        }
                    }
                    if failedCount > 0 {
                        Text(polish: failedCount == 1
                             ? "jednego zdjęcia nie udało mi się otworzyć – spróbuj wybrać je jeszcze raz"
                             : "kilku zdjęć nie udało mi się otworzyć – spróbuj wybrać je jeszcze raz")
                            .font(.footnote)
                            .foregroundStyle(Palette.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isAdding)
        .accessibilityLabel("dodaj zdjęcia z galerii")
    }

    private func tile(_ photo: ProgressPhoto) -> some View {
        Button {
            shownPhoto = photo
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        PhotoFileImage(url: store.photoURL(photo), maxPixelSize: 480, fills: true)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(PolishDate.short(photo.day))
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("zdjęcie z \(PolishDate.dayMonth(photo.day))")
    }

    /// Keeps a smaller JPEG copy of each picked photo for today. Each is converted away from the
    /// main thread, one at a time.
    private func add(_ items: [PhotosPickerItem], to store: AppStore) async {
        isAdding = true
        failedCount = 0
        var failed = 0
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
        }
        failedCount = failed
        isAdding = false
    }
}

/// One photo, large, with its day. Removing it asks once more.
private struct PhotoDetailSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let photo: ProgressPhoto
    @State private var isAskingToRemove = false

    var body: some View {
        let url = store.photoURL(photo)
        let isThere = FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
        NavigationStack {
            VStack(spacing: 16) {
                if isThere {
                    PhotoFileImage(url: url, maxPixelSize: 2048)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                    Text(polish: "nie mogę znaleźć tego zdjęcia w telefonie. Mogło zniknąć, gdy wczytywałam kopię Twoich danych – możesz usunąć ten wpis")
                        .bodyText()
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                Button("usuń to zdjęcie") {
                    isAskingToRemove = true
                }
                .buttonStyle(LinkButtonStyle())
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)
            .navigationTitle(InnerFormat.date(photo.day, today: store.today))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("gotowe")
                }
            }
            .confirmationDialog("usunąć to zdjęcie?", isPresented: $isAskingToRemove, titleVisibility: .visible) {
                Button("usuń zdjęcie") {
                    store.removePhoto(photo.id)
                    dismiss()
                }
                Button("zostaw", role: .cancel) {}
            } message: {
                Text(polish: "usunę je z aplikacji i nie da się go już przywrócić")
            }
        }
        .presentationDetents([.large])
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
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
