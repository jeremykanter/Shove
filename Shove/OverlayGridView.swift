//
//  OverlayGridView.swift
//  Shove
//

import SwiftUI

/// The overlay panel's state; mutated by OverlayController on each shove.
@MainActor @Observable
final class OverlayModel {
    var content: OverlayContent = .indicator(.center)
}

/// The overlay: a 12×4 miniature of the screen with the window's cells lit,
/// or — for the move-only shortcuts — a dot in the matching part of an empty
/// frame. Both share the same stroked, blurred enclosure.
struct OverlayGridView: View {
    let model: OverlayModel

    private static let cellSize = CGSize(width: 8, height: 16)
    private static let spacing: CGFloat = 2
    private static let cornerRadius: CGFloat = 32
    private static let bodyWidth =
        CGFloat(GridHighlight.columns) * cellSize.width + CGFloat(GridHighlight.columns - 1) * spacing
    private static let bodyHeight =
        CGFloat(GridHighlight.rows) * cellSize.height + CGFloat(GridHighlight.rows - 1) * spacing

    var body: some View {
        let enclosure = content
            .frame(width: Self.bodyWidth, height: Self.bodyHeight)
            .padding(8)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.grid, lineWidth: 4)
            }

        Group {
            if #available(macOS 26.0, *) {
                enclosure
                    .padding(24)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
            } else {
                enclosure
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.content {
        case .grid(let highlight):
            grid(highlight)
        case .indicator(let indicator):
            dot(indicator)
        }
    }

    private func grid(_ highlight: GridHighlight) -> some View {
        Grid(horizontalSpacing: Self.spacing, verticalSpacing: Self.spacing) {
            ForEach(0..<GridHighlight.rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<GridHighlight.columns, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(highlight.contains(column: column, row: row)
                                  ? AnyShapeStyle(.grid)
                                  : AnyShapeStyle(.grid.opacity(0.2)))
                            .frame(width: Self.cellSize.width, height: Self.cellSize.height)
                    }
                }
            }
        }
    }

    private func dot(_ indicator: Indicator) -> some View {
        Circle()
            .fill(.grid)
            .frame(width: 12, height: 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: indicator.alignment)
    }
}

private extension Indicator {
    var alignment: Alignment {
        switch self {
        case .topLeft: .topLeading
        case .topRight: .topTrailing
        case .center: .center
        }
    }
}

#Preview {
    let model = OverlayModel()
    model.content = .grid(GridHighlight(columnRange: 0..<5, rowRange: 0..<4))
    return OverlayGridView(model: model)
        .padding(40)
}
