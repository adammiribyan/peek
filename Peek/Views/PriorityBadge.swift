import SwiftUI

struct PriorityBadge: View {
    let name: String

    private var icon: String {
        switch name.lowercased() {
        case "highest", "critical": "chevron.up.2"
        case "high": "chevron.up"
        case "medium": "equal"
        case "low": "chevron.down"
        case "lowest": "chevron.down.2"
        default: "minus"
        }
    }

    private var color: Color {
        switch name.lowercased() {
        case "highest", "critical": .red
        case "high": .orange
        case "medium": .yellow
        case "low": .blue
        case "lowest": .gray
        default: .gray
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(name)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
    }
}
