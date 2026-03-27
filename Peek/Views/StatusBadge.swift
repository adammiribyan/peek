import SwiftUI

struct StatusBadge: View {
    let name: String
    let categoryKey: String?

    private var color: Color {
        switch categoryKey {
        case "new": .gray
        case "indeterminate": .blue
        case "done": .green
        default: .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(name)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(.capsule)
    }
}
