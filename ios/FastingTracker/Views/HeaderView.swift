import SwiftUI

struct HeaderView: View {
    @Environment(FastingStore.self) private var store

    let visibleDates: [Date]
    let onPrev: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    private var fastCount: Int {
        store.countFasts(visibleDates: visibleDates)
    }

    private var weekLabel: String {
        guard visibleDates.count == 7 else { return "" }
        let cal = Calendar.current
        let s = visibleDates.first!, e = visibleDates.last!
        let sm = cal.component(.month, from: s), sd = cal.component(.day, from: s)
        let em = cal.component(.month, from: e), ed = cal.component(.day, from: e)
        return sm == em ? "\(sm)/\(sd) – \(ed)" : "\(sm)/\(sd) – \(em)/\(ed)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title row
            HStack(spacing: 8) {
                Text("Fasting Tracker")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(white: 0.90))
                Spacer()
                fastBadge
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Navigation row
            HStack(spacing: 6) {
                navButton("◀", action: onPrev)
                Text(weekLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.79))
                    .frame(minWidth: 110)
                navButton("▶", action: onNext)
                todayButton
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .background(Color(red: 0.051, green: 0.067, blue: 0.090))
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color(white: 0.13))
        }
    }

    private var fastBadge: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text("\(fastCount)")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Color(red: 0.051, green: 0.067, blue: 0.090))
            Text("FASTS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(red: 0.051, green: 0.067, blue: 0.090))
                .tracking(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.824, blue: 0.706),
                    Color(red: 0.0, green: 0.659, blue: 0.588)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(Capsule())
        )
    }

    private func navButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color(red: 0.345, green: 0.651, blue: 1.0))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var todayButton: some View {
        Button(action: onToday) {
            Text("今日")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(red: 0.345, green: 0.651, blue: 1.0))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(white: 0.19), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
