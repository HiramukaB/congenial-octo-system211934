import SwiftUI

/// Lays its children out like words in a sentence: side by side, and onto the next line when the
/// next one doesn't fit. Short links ("nie znam jeszcze: …") wrap this way instead of being
/// squeezed into narrow columns, also at larger text sizes.
///
/// `nonisolated`, like `OrganicStar`: SwiftUI may run layout code off the main thread.
nonisolated struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let lines = arrange(subviews, maxWidth: maxWidth)
        let contentWidth = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, lines.count - 1))
        // Taking the whole offered width means the lines are placed exactly as they were measured.
        let width = maxWidth.isFinite ? max(maxWidth, contentWidth) : contentWidth
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrange(subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for item in line.items {
                // Centred on its line, so a label and the links after it share one middle.
                let origin = CGPoint(x: x, y: y + (line.height - item.size.height) / 2)
                subviews[item.index].place(at: origin, anchor: .topLeading, proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [FlowLine] {
        var lines: [FlowLine] = []
        var line = FlowLine()
        for index in subviews.indices {
            let itemSize = measure(subviews[index], maxWidth: maxWidth)
            if !line.items.isEmpty && line.width + spacing + itemSize.width > maxWidth {
                lines.append(line)
                line = FlowLine()
            }
            line.width += (line.items.isEmpty ? 0 : spacing) + itemSize.width
            line.height = max(line.height, itemSize.height)
            line.items.append((index: index, size: itemSize))
        }
        if !line.items.isEmpty {
            lines.append(line)
        }
        return lines
    }

    /// A child's natural size; one wider than a whole line wraps its own text to fit.
    private func measure(_ subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        guard maxWidth.isFinite, natural.width > maxWidth else { return natural }
        return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
    }
}

/// One line of a `FlowLayout`: which children it holds, at what size, and how big it is.
nonisolated struct FlowLine {
    var items: [(index: Int, size: CGSize)] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
}
