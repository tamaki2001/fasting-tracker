import SwiftUI

struct HeaderView: View {
    @Environment(FastingStore.self) private var store

    let visibleDates: [Date]
    let onPrev: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    @State private var showSettings = false
    @State private var now = Date()
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var okCount: Int {
        store.countOK(visibleDates: visibleDates)
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
                settingsButton
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    .environment(store)
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }

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
            .padding(.bottom, 4)

            // カウントダウン行（次の食事の期限が残っている間のみ表示）
            if let label = countdownLabel {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .semibold))
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.0, green: 0.824, blue: 0.706))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
            }
        }
        .background(Color(red: 0.051, green: 0.067, blue: 0.090))
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color(white: 0.13))
        }
        .onReceive(minuteTimer) { now = $0 }
    }

    // 次の食事の期限までの残り時間。窓を過ぎていれば nil を返す
    private var countdownLabel: String? {
        guard let lastMeal = store.lastMealDate else { return nil }
        let elapsed = now.timeIntervalSince(lastMeal)
        let target = TimeInterval(store.intervalHours * 3600)
        let remaining = target - elapsed
        guard remaining > 0 else { return nil }

        let totalMin = Int(remaining / 60)
        let h = totalMin / 60
        let m = totalMin % 60
        let timeStr: String
        if h > 0 && m > 0 { timeStr = "\(h)時間\(m)分" }
        else if h > 0      { timeStr = "\(h)時間" }
        else               { timeStr = "\(m)分" }
        return "次の食事まであと\(timeStr)"
    }

    private var fastBadge: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text("\(okCount)")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Color(red: 0.051, green: 0.067, blue: 0.090))
            Text("OK")
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

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.54))
        }
        .buttonStyle(.plain)
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

// MARK: - SettingsSheet

private struct SettingsSheet: View {
    @Environment(FastingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let hourOptions = Array(2...12)

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            VStack(spacing: 0) {
                // 説明テキスト
                Text("前の食事からこの時間以内に\n次の食事を摂れると「OK」になります")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.54))
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                // ホイールピッカー
                Picker("目標間隔", selection: $store.intervalHours) {
                    ForEach(hourOptions, id: \.self) { h in
                        Text("\(h) 時間").tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 140)

                Spacer()
            }
            .navigationTitle("食事間隔の目標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .background(Color(red: 0.09, green: 0.11, blue: 0.14))
        }
        .preferredColorScheme(.dark)
    }
}
