import Combine
import Foundation
import SwiftUI
import Swinject

// 🟢 NEU: Hochperformantes natives Layout (ersetzt den GeometryReader-Hack)
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for row in result.rows {
            let rowYOffset = row.map(\.yOffset).min() ?? 0
            for index in row.indices {
                let x = bounds.minX + row[index].xOffset
                let y = bounds.minY + row[index].yOffset - rowYOffset + result.rowOffsets[row[index].rowIndex]
                subviews[row[index].index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(row[index].size))
            }
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var rows: [[(index: Int, size: CGSize, xOffset: CGFloat, yOffset: CGFloat, rowIndex: Int)]] = []
        var rowOffsets: [CGFloat] = []

        init(in maxWidth: CGFloat, subviews: Layout.Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var currentRowMaxHeight: CGFloat = 0
            var currentRow: [(index: Int, size: CGSize, xOffset: CGFloat, yOffset: CGFloat, rowIndex: Int)] = []
            var rowIndex = 0

            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth, !currentRow.isEmpty {
                    rows.append(currentRow)
                    rowOffsets.append(currentY)
                    currentRow = []
                    currentX = 0
                    currentY += currentRowMaxHeight + spacing
                    currentRowMaxHeight = 0
                    rowIndex += 1
                }
                currentRow.append((index, size, currentX, currentY, rowIndex))
                currentX += size.width + spacing
                currentRowMaxHeight = max(currentRowMaxHeight, size.height)
            }
            if !currentRow.isEmpty {
                rows.append(currentRow)
                rowOffsets.append(currentY)
            }
            size = CGSize(width: maxWidth, height: currentY + currentRowMaxHeight)
        }
    }
}

struct TagCloudView: View {
    var tags: [String]

    var body: some View {
        // 🟢 Die UI ist jetzt extrem sauber und blitzschnell!
        FlowLayout(spacing: 6) {
            ForEach(self.tags, id: \.self) { tag in
                self.item(for: tag)
            }
        }
    }

    private func item(for textTag: String) -> some View {
        var colorOfTag: Color {
            switch textTag {
            case let t where t.contains("SMB Delivery Ratio:"):
                return .uam
            case let t where t.contains("Bolus") || t.contains("Insulin 24h:"):
                return .purple
            case let t
                where t.contains("tdd_factor") || t.contains("Sigmoid") || t.contains("Logarithmic") || t.contains("AF:") || t
                .contains("Autosens/Dynamic Limit:") || t.contains("Dynamic ISF/CR") || t.contains("Dynamic Ratio") || t
                .contains("Auto ISF"):
                return .purple
            case let t where t.contains("Middleware:"):
                return .red
            default:
                return .insulin
            }
        }

        return Text(textTag)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .background(colorOfTag.opacity(0.85))
            .foregroundColor(.white)
            .cornerRadius(6)
            // 🟢 Räumlicher Schatten für die Tags
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

struct TestTagCloudView: View {
    var body: some View {
        VStack {
            Text("Header").font(.largeTitle)
            TagCloudView(tags: ["Ninetendo", "XBox", "PlayStation", "PlayStation 2", "PlayStation 3", "PlayStation 4"])
            Text("Some other text")
            Divider()
            Text("Some other cloud")
            TagCloudView(tags: ["Apple", "Google", "Amazon", "Microsoft", "Oracle", "Facebook"])
        }
    }
}
