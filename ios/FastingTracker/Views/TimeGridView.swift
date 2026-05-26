import SwiftUI

// MARK: - Constants
private let slots = 48
private let timeWidth: CGFloat = 30
private let rowHeight: CGFloat = 34
private let bufferCount = 21
private let visibleCount = 7
private let dowNames = ["日", "月", "火", "水", "木", "金", "土"]

// MARK: - TimeGridView

struct TimeGridView: View {
    @Environment(FastingStore.self) private var store

    @Binding var anchorDayOffset: Int
    let onVisibleDatesChange: ([Date]) -> Void

    // Horizontal pan state
    @State private var pixelOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var dragAxis: DragAxis = .undetermined

    // Column width: UIScreen で初期値を設定し、onGeometryChange で正確な値に更新
    // GeometryReader を body のレイアウトに使わないことでギャップ問題を回避する
    @State private var colW: CGFloat = (UIScreen.main.bounds.width - timeWidth) / CGFloat(visibleCount)

    // Current time — refreshed every minute for the "now" indicator
    @State private var nowSlot: Int = currentNowSlot()
    @State private var todayStr: String = ""
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var homeOffset: CGFloat { CGFloat(visibleCount) * colW }

    // 21-day buffer centered on anchorDayOffset
    private var bufferDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: anchorDayOffset, to: today) ?? today
        return (0..<bufferCount).map { i in
            cal.date(byAdding: .day, value: i - 13, to: end) ?? today
        }
    }

    // The 7 dates currently visible
    private var visibleDates: [Date] {
        let shift = Int(((pixelOffset - homeOffset) / colW).rounded())
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: anchorDayOffset + shift, to: today) ?? today
        return (-6...0).map { cal.date(byAdding: .day, value: $0, to: end) ?? today }
    }

    var body: some View {
        // GeometryReader をレイアウトに使わず、VStack を直接配置する
        // これにより dayHeaderStrip が必ずヘッダー直下に来る
        VStack(spacing: 0) {
            dayHeaderStrip
            Divider().background(Color(white: 0.13))
            mainGrid
        }
        // 幅の測定は onGeometryChange（iOS 17）で行う（レイアウトに影響しない）
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { newWidth in
            let newColW = (newWidth - timeWidth) / CGFloat(visibleCount)
            guard abs(newColW - colW) > 0.5 else { return }
            colW = newColW
            pixelOffset = homeOffset
        }
        .onAppear {
            pixelOffset = homeOffset
            todayStr = store.dateString(Date())
            onVisibleDatesChange(visibleDates)
        }
        .onChange(of: anchorDayOffset) {
            pixelOffset = homeOffset
            onVisibleDatesChange(visibleDates)
        }
        .onReceive(minuteTimer) { _ in
            nowSlot = Self.currentNowSlot()
            todayStr = store.dateString(Date())
        }
        .gesture(horizontalDragGesture)
    }

    // MARK: - Day header strip

    // ZStack に maxWidth: .infinity を指定して「21列分の幅」を親に報告させない
    private var dayHeaderStrip: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeWidth, height: 46)
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(bufferDates, id: \.self) { date in
                        DayHeaderCell(date: date, colW: colW, todayStr: todayStr)
                    }
                }
                .offset(x: -pixelOffset)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .frame(height: 46) // 高さを明示して VStack のレイアウトを安定させる
    }

    // MARK: - Main scrollable grid

    @State private var scrollProxy: ScrollViewProxy? = nil

    private var mainGrid: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    timeColumn
                    cellStrip
                }
                .padding(.bottom, 44)
            }
            .onAppear {
                scrollProxy = proxy
                DispatchQueue.main.async {
                    proxy.scrollTo("time-\(max(0, nowSlot - 4))", anchor: .top)
                }
            }
            .simultaneousGesture(horizontalDragGesture)
        }
    }

    private var timeColumn: some View {
        VStack(spacing: 0) {
            ForEach(0..<slots, id: \.self) { slot in
                ZStack {
                    Color.clear.frame(width: timeWidth, height: rowHeight)
                    if slot % 2 == 0 {
                        Text(String(format: "%02d", slot / 2))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(white: 0.62))
                            .monospacedDigit()
                    } else {
                        Text("30")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(white: 0.36))
                    }
                }
                .id("time-\(slot)")
            }
        }
        .frame(width: timeWidth)
    }

    private var cellStrip: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                ForEach(bufferDates, id: \.self) { date in
                    DayColumn(
                        date: date,
                        colW: colW,
                        nowSlot: nowSlot,
                        todayStr: todayStr
                    )
                }
            }
            .offset(x: -pixelOffset)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    // MARK: - Horizontal drag gesture

    private var horizontalDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let dx = abs(value.translation.width)
                let dy = abs(value.translation.height)

                if dragAxis == .undetermined {
                    if dx > dy + 5 {
                        dragAxis = .horizontal
                        dragStartOffset = pixelOffset
                    } else if dy > dx + 5 {
                        dragAxis = .vertical
                    }
                    return
                }

                guard dragAxis == .horizontal else { return }
                pixelOffset = dragStartOffset - value.translation.width
            }
            .onEnded { value in
                defer { dragAxis = .undetermined }
                guard dragAxis == .horizontal else { return }

                let predictedDx = value.predictedEndTranslation.width
                let finalOffset = dragStartOffset - predictedDx
                let shift = (finalOffset - homeOffset) / colW
                let rounded = Int(shift.rounded())
                let snappedOffset = homeOffset + CGFloat(rounded) * colW

                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    pixelOffset = snappedOffset
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    if rounded != 0 {
                        anchorDayOffset += rounded
                    }
                    onVisibleDatesChange(visibleDates)
                }
            }
    }

    // MARK: - Helpers

    private enum DragAxis { case undetermined, horizontal, vertical }

    private static func currentNowSlot() -> Int {
        let now = Date()
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        return h * 2 + (m >= 30 ? 1 : 0)
    }
}

// MARK: - DayHeaderCell

private struct DayHeaderCell: View {
    let date: Date
    let colW: CGFloat
    let todayStr: String

    private var cal: Calendar { .current }

    private var isToday: Bool {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date) == todayStr
    }

    private var dowIndex: Int { cal.component(.weekday, from: date) - 1 }
    private var dayNum: Int { cal.component(.day, from: date) }

    var body: some View {
        VStack(spacing: 1) {
            Text(dowNames[dowIndex])
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(white: 0.54))
            ZStack {
                Circle()
                    .fill(isToday ? Color(red: 0.345, green: 0.651, blue: 1.0) : Color.clear)
                    .frame(width: 24, height: 24)
                Text("\(dayNum)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        isToday
                            ? Color(red: 0.051, green: 0.067, blue: 0.090)
                            : Color(white: 0.79)
                    )
            }
        }
        .frame(width: colW, height: 38)
    }
}

// MARK: - DayColumn

private struct DayColumn: View {
    @Environment(FastingStore.self) private var store

    let date: Date
    let colW: CGFloat
    let nowSlot: Int
    let todayStr: String

    private var cal: Calendar { .current }

    private var dateStr: String { store.dateString(date) }
    private var isToday: Bool { dateStr == todayStr }

    private var isWeekend: Bool {
        let dow = cal.component(.weekday, from: date)
        return dow == 1 || dow == 7
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<slots, id: \.self) { slot in
                CellView(
                    state: store.state(date: date, slot: slot),
                    isFasting: store.fastSet.contains("\(dateStr):\(slot)"),
                    isWeekend: isWeekend,
                    isNow: isToday && slot == nowSlot
                )
                .frame(width: colW, height: rowHeight)
                .contentShape(Rectangle())
                .onTapGesture { store.toggle(date: date, slot: slot) }
            }
        }
    }
}

// MARK: - CellView

private struct CellView: View {
    let state: CellState?
    let isFasting: Bool
    let isWeekend: Bool
    let isNow: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(bgColor)
                .overlay(
                    Rectangle()
                        .stroke(Color(white: 0.11), lineWidth: 0.5)
                )
                .overlay(
                    isNow
                        ? AnyView(Rectangle().stroke(Color(red: 0.345, green: 0.651, blue: 1.0), lineWidth: 2))
                        : AnyView(EmptyView())
                )

            if let state {
                Text(state.icon)
                    .font(.system(
                        size: state == .meal ? 15 : 13,
                        weight: .bold
                    ))
                    .foregroundStyle(
                        state == .meal
                            ? Color(red: 1.0, green: 0.549, blue: 0.259)
                            : Color(red: 1.0, green: 0.820, blue: 0.400)
                    )
            }
        }
    }

    private var bgColor: Color {
        if let state {
            return state == .meal
                ? Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.24)
                : Color(red: 1.0, green: 0.820, blue: 0.400).opacity(0.20)
        }
        if isFasting { return Color(red: 0.0, green: 0.824, blue: 0.706).opacity(0.13) }
        if isWeekend { return Color.white.opacity(0.018) }
        return Color.clear
    }
}
