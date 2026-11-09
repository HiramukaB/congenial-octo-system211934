import SwiftUI

extension View {
    /// Puts the slowly drifting night background behind the view.
    /// `tint` gently colours it with the current phase of the cycle.
    func ambientBackground(tint: Color? = nil) -> some View {
        background {
            AmbientBackground(tint: tint)
        }
    }
}

/// Native take on the web background: drifting warm light, twinkling stars, film grain and a vignette.
struct AmbientBackground: View {
    var tint: Color?
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        let colors = meshColors
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                MeshGradient(width: 3, height: 3, points: AmbientBackground.meshPoints(at: time), colors: colors)
                StarField(time: time)
            }
        }
        .overlay {
            GrainTexture.image
                .resizable(resizingMode: .tile)
                .blendMode(.softLight)
                .opacity(0.4)
        }
        .overlay {
            EllipticalGradient(colors: [.clear, .black.opacity(0.55)],
                               center: .center,
                               startRadiusFraction: 0.4,
                               endRadiusFraction: 1.0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }

    private var meshColors: [Color] {
        let warmCore = Color(hex: 0x3A3128)
        let warmSide = Color(hex: 0x241F1A)
        let core = tint.map { warmCore.mix(with: $0, by: 0.3) } ?? warmCore
        let side = tint.map { warmSide.mix(with: $0, by: 0.15) } ?? warmSide
        return [
            Color(hex: 0x1D1A16), Color(hex: 0x2A241C), Color(hex: 0x16171B),
            side, core, Color(hex: 0x1E2125),
            Color(hex: 0x0E0D0C), Color(hex: 0x1B1C1F), Color(hex: 0x0B0A09)
        ]
    }

    /// Corners stay put; edge and centre points drift on 34–46 s loops like the old CSS blobs.
    static func meshPoints(at time: TimeInterval) -> [SIMD2<Float>] {
        func drift(_ period: Double, _ amplitude: Double, _ offset: Double) -> Float {
            Float(0.5 + sin(time * 2 * Double.pi / period + offset) * amplitude)
        }
        let top = SIMD2<Float>(drift(41, 0.12, 0), 0)
        let left = SIMD2<Float>(0, drift(37, 0.10, 1))
        let center = SIMD2<Float>(drift(34, 0.14, 2), drift(46, 0.12, 3))
        let right = SIMD2<Float>(1, drift(43, 0.10, 4))
        let bottom = SIMD2<Float>(drift(39, 0.12, 5), 1)
        return [
            SIMD2<Float>(0, 0), top, SIMD2<Float>(1, 0),
            left, center, right,
            SIMD2<Float>(0, 1), bottom, SIMD2<Float>(1, 1)
        ]
    }
}

/// A few dozen faint stars that slowly twinkle.
struct StarField: View {
    let time: TimeInterval

    struct Star {
        let x: Double
        let y: Double
        let radius: Double
        let brightness: Double
        let period: Double
        let phase: Double
    }

    static let stars: [Star] = {
        var generator = SeededGenerator(seed: 0x57A2_F1E1D)
        return (0..<42).map { _ in
            Star(x: Double.random(in: 0...1, using: &generator),
                 y: Double.random(in: 0...1, using: &generator),
                 radius: Double.random(in: 0.4...0.9, using: &generator),
                 brightness: Double.random(in: 0.25...0.55, using: &generator),
                 period: Double.random(in: 6...14, using: &generator),
                 phase: Double.random(in: 0...(2 * Double.pi), using: &generator))
        }
    }()

    var body: some View {
        let stars = StarField.stars
        let starColor = Color(hex: 0xF0EBE1)
        let now = time
        Canvas { context, size in
            for star in stars {
                let twinkle = 0.6 + 0.4 * sin(now / star.period * 2 * .pi + star.phase)
                context.opacity = star.brightness * twinkle
                let rect = CGRect(x: star.x * size.width - star.radius,
                                  y: star.y * size.height - star.radius,
                                  width: star.radius * 2,
                                  height: star.radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(starColor))
            }
        }
    }
}

/// Film grain generated once from seeded noise (no image files needed).
enum GrainTexture {
    static let image: Image = makeImage()

    private static func makeImage() -> Image {
        let side = 128
        var generator = SeededGenerator(seed: 0xAB0_7E12)
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        for pixel in 0..<(side * side) {
            let value = UInt8.random(in: 0...255, using: &generator)
            bytes[pixel * 4] = value
            bytes[pixel * 4 + 1] = value
            bytes[pixel * 4 + 2] = value
            bytes[pixel * 4 + 3] = 255
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cgImage = CGImage(width: side,
                                    height: side,
                                    bitsPerComponent: 8,
                                    bitsPerPixel: 32,
                                    bytesPerRow: side * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                    provider: provider,
                                    decode: nil,
                                    shouldInterpolate: false,
                                    intent: .defaultIntent)
        else {
            return Image(systemName: "circle.fill")
        }
        return Image(decorative: cgImage, scale: 2)
    }
}

/// Deterministic random numbers (SplitMix64), so stars and grain look the same on every launch.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}
