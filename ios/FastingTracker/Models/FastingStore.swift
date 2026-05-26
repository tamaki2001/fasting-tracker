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
    private(set) var fastSet: Set<String> = []

    /// 断食と判定する最低時間（時間単位）。変更すると即座に再計算される。
    var fastingHours: Int = 12 {
        didSet {
            UserDefaults.standard.set(fastingHours, forKey: "fasting-hours")
            recomputeFasting()
        }
    }

    private let storageKey = "fasting-data"
    private let cal = Calendar.current

    init() {
        fastingHours = UserDefaults.standard.integer(forKey: "fasting-hours")
            .clamped(to: 10...36) // 0 が返ったときのデフォルト
        if fastingHours == 0 { fastingHours = 12 }
        load()
        recomputeFasting()
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
        recomputeFasting()
        scheduleNotifications(after: date, slot: slot)
    }

    func countFasts(visibleDates: [Date]) -> Int {
        let visibleStrings = Set(visibleDates.map { dateString($0) })
        return fastPeriods.filter { period in
            period.contains { visibleStrings.contains($0) }
        }.count
    }

    // MARK: - Fasting Calculation

    private var fastPeriods: [Set<String>] = []

    private func recomputeFasting() {
        let slots = 48
        let threshold = fastingHours * 2  // 30分スロット単位に変換

        var events: [(dateStr: String, slot: Int)] = []
        for dateStr in dayData.keys.sorted() {
            guard let dd = dayData[dateStr] else { continue }
            for slot in dd.keys.sorted() {
                events.append((dateStr: dateStr, slot: slot))
            }
        }

        var newFastSet = Set<String>()
        var newPeriods: [Set<String>] = []

        guard events.count > 1 else {
            fastSet = newFastSet
            fastPeriods = newPeriods
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
            guard gap >= threshold else { continue }

            var cd = dateA
            var cs = a.slot + 1
            if cs >= slots { cs = 0; cd = addDays(cd, 1) }

            var periodDays = Set<String>()
            while true {
                let cds = dateString(cd)
                if cds > b.dateStr || (cds == b.dateStr && cs >= b.slot) { break }
                newFastSet.insert("\(cds):\(cs)")
                periodDays.insert(cds)
                cs += 1
                if cs >= slots { cs = 0; cd = addDays(cd, 1) }
            }
            if !periodDays.isEmpty { newPeriods.append(periodDays) }
        }

        fastSet = newFastSet
        fastPeriods = newPeriods
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
        let slotDate = cal.date(
            byAdding: .minute, value: slot * 30,
            to: cal.startOfDay(for: date)
        ) ?? date

        // Only schedule if this is a meal/snack (not a clear)
        let key = dateString(date)
        guard dayData[key]?[slot] != nil else { return }

        NotificationManager.shared.scheduleFastingAchievement(from: slotDate, hours: fastingHours)
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
