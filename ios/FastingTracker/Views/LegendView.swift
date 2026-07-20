import SwiftUI

struct LegendView: View {
    var body: some View {
        HStack(spacing: 14) {
            legendItem(color: Color(red: 1.0, green: 0.549, blue: 0.259), label: "◯ 食事")
            legendItem(color: Color(red: 1.0, green: 0.820, blue: 0.400), label: "△ 間食")
            legendItem(color: Color(red: 0.0, green: 0.824, blue: 0.706).opacity(0.5), label: "6h以内")
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.clear, Color(red: 0.051, green: 0.067, blue: 0.090)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.54))
        }
    }
}
