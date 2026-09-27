import SwiftUI

/// Categorical colours for board columns, assigned by board order (Done last), never cycled.
/// The order is CVD-checked for adjacent pairs; light and dark are separate steps of the same hues.
enum BoardPalette {
    private static let slots: [(light: UInt32, dark: UInt32)] = [
        (0x2A78D6, 0x3987E5), // blue
        (0xEB6834, 0xD95926), // orange
        (0x1BAF7A, 0x199E70), // aqua
        (0xEDA100, 0xC98500), // yellow
        (0xE87BA4, 0xD55181), // magenta
        (0x008300, 0x008300), // green
        (0x4A3AA7, 0x9085E9), // violet
        (0xE34948, 0xE66767), // red
    ]

    static func color(_ slot: Int) -> Color {
        guard slots.indices.contains(slot) else { return .gray }
        let pair = slots[slot]
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: pair.dark) : UIColor(hex: pair.light) })
    }

    /// Colours for `BoardMetrics.columnNames(config)`, in the same order.
    static func colors(_ config: BoardConfig) -> [Color] {
        BoardMetrics.columnNames(config).indices.map(color)
    }

    /// Colour of the column a card shows in.
    static func color(of card: BoardCard, in config: BoardConfig) -> Color {
        guard let column = config.column(of: card) else { return color(config.columns.count) }
        return color(config.columns.firstIndex { $0.id == column.id } ?? 0)
    }
}

/// Wrapping legend: a coloured dot beside each name; names stay in text ink.
struct BoardLegend: View {
    let items: [(name: String, color: Color)]

    var body: some View {
        items.reduce(Text("")) { text, item in
            text + Text(Image(systemName: "circle.fill")).font(.system(size: 8)).foregroundStyle(item.color)
                + Text(" \(item.name)   ")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
