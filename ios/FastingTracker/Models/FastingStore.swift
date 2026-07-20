import Foundation
import Observation

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

enum CellState: String, Codable, Equatable {
    case meal
    case snack

    var next: CellState? {
        switch self {
        case .meal: return .snack
        case .snack: return nil
        }
    }

    var icon: String {
        switch self {
        case .meal: return "◯"
        case .snack: return "△"
        }
    }
}

@Observable
final class FastingStore {
    // dayData["2024-01-15"][26] = .meal  (slot 26 = 13:00)
    private(set) var dayData: [String: [Int: CellState]] = [:]
    // OK と判定された空白セル ("2024-01-15:27" 形式)
    private(set) var okSet: Set<String> = []

    /// 目標とする食事間隔（時間単位）。この時間「以内」に次の食事を摂れたら OK。
    /// 変更すると即座に再計算される。
    var intervalHours: Int = 6 {
        didSet {
            UserDefaults.standard.set(intervalHours, forKey: "interval-hours")
            recomputeOK()
        }
    }

    private let storageKey = "fasting-data"
    private let cal = Calendar.current

    init() {
        intervalHours = UserDefaults.standard.integer(forKey: "interval-hours")
            .clamped(to: 2...12) // 0 が返ったときのデフォルト
        if intervalHours == 0 { intervalHours = 6 }
        load()
        recomputeOK()
    }

    // MARK: - Public API

    func state(date: Date, slot: Int) -> CellState? {
        dayData[dateString(date)]?[slot]
    }

    func toggle(date: Date, slot: Int) {
        let key = dateString(date)
        let current = dayData[key]?[slot]

        var dd = dayData[key] ?? [:]
        if let current {
            if let next = current.next {
                dd[slot] = next
            } else {
                dd.removeValue(forKey: slot)
            }
        } else {
            dd[slot] = .meal
        }

        if dd.isEmpty {
            dayData.removeValue(forKey: key)
        } else {
            dayData[key] = dd
        }

        save()
        recomputeOK()
        scheduleNotifications(after: date, slot: slot)
    }

    /// 直近の「食事(◯)」が記録された時刻（スロット単位で変換済み）。
    /// 間食(△)は判定に影響しないため無視する。
    var lastMealDate: Date? {
        var bestDateStr: String = ""
        var bestSlot: Int = -1
        for dateStr in dayData.keys {
            guard let dd = dayData[dateStr] else { continue }
            for (slot, cell) in dd where cell == .meal {
                if dateStr > bestDateStr || (dateStr == bestDateStr && slot > bestSlot) {
                    bestDateStr = dateStr
                    bestSlot = slot
                }
            }
        }
        guard bestSlot >= 0, let base = parseDate(bestDateStr) else { return nil }
        return cal.date(byAdding: .minute, value: bestSlot * 30, to: base)
    }

    func countOK(visibleDates: [Date]) -> Int {
        let visibleStrings = Set(visibleDates.map { dateString($0) })
        return okPeriods.filter { period in
            period.contains { visibleStrings.contains($0) }
        }.count
    }

    // MARK: - OK Calculation

    private var okPeriods: [Set<String>] = []

    /// 連続する「食事(◯)」の間隔が目標時間「以内」なら、その間の空白セルを OK として塗る。
    /// 間食(△)はイベントとして数えず、純粋な記録として無視する。
    private func recomputeOK() {
        let slots = 48
        let threshold = intervalHours * 2  // 30分スロット単位に変換

        var events: [(dateStr: String, slot: Int)] = []
        for dateStr in dayData.keys.sorted() {
            guard let dd = dayData[dateStr] else { continue }
            for slot in dd.keys.sorted() where dd[slot] == .meal {
                events.append((dateStr: dateStr, slot: slot))
            }
        }

        var newOKSet = Set<String>()
        var newPeriods: [Set<String>] = []

        guard events.count > 1 else {
            okSet = newOKSet
            okPeriods = newPeriods
            return
        }

        for i in 0..<(events.count - 1) {
            let a = events[i], b = events[i + 1]
            guard
                let dateA = parseDate(a.dateStr),
                let dateB = parseDate(b.dateStr)
            else { continue }

            let dayDiff = cal.dateComponents([.day], from: dateA, to: dateB).day ?? 0
            let gap = dayDiff * slots + (b.slot - a.slot)
            // 6時間「以内」で次の食事を摂れていれば OK
            guard gap <= threshold else { continue }

            var cd = dateA
            var cs = a.slot + 1
            if cs >= slots { cs = 0; cd = addDays(cd, 1) }

            var periodDays = Set<String>()
            while true {
                let cds = dateString(cd)
                if cds > b.dateStr || (cds == b.dateStr && cs >= b.slot) { break }
                newOKSet.insert("\(cds):\(cs)")
                periodDays.insert(cds)
                cs += 1
                if cs >= slots { cs = 0; cd = addDays(cd, 1) }
            }
            // 隣接（間に空白なし）でも 1 本の OK として数える
            periodDays.insert(a.dateStr)
            newPeriods.append(periodDays)
        }

        okSet = newOKSet
        okPeriods = newPeriods
    }

    // MARK: - Persistence

    func save() {
        var encodable: [String: [String: String]] = [:]
        for (dateStr, slots) in dayData {
            encodable[dateStr] = Dictionary(
                uniqueKeysWithValues: slots.map { ("\($0.key)", $0.value.rawValue) }
            )
        }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data)
        else { return }

        dayData = [:]
        for (dateStr, slots) in decoded {
            var dd: [Int: CellState] = [:]
            for (slotStr, stateStr) in slots {
                if let slot = Int(slotStr), let state = CellState(rawValue: stateStr) {
                    dd[slot] = state
                }
            }
            if !dd.isEmpty { dayData[dateStr] = dd }
        }
    }

    // MARK: - Notifications

    private func scheduleNotifications(after date: Date, slot: Int) {
        // 通知は「食事(◯)」を起点にのみスケジュールする。間食(△)や消去では変更しない。
        let key = dateString(date)
        guard dayData[key]?[slot] == .meal else { return }

        let slotDate = cal.date(
            byAdding: .minute, value: slot * 30,
            to: cal.startOfDay(for: date)
        ) ?? date

        NotificationManager.shared.scheduleNextMealReminder(from: slotDate, hours: intervalHours)
    }

    // MARK: - Helpers

    func dateString(_ date: Date) -> String {
        let d = cal.startOfDay(for: date)
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    func parseDate(_ string: String) -> Date? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        return cal.date(from: DateComponents(year: y, month: m, day: d))
    }

    func addDays(_ date: Date, _ n: Int) -> Date {
        cal.date(byAdding: .day, value: n, to: date) ?? date
    }
}
