import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    func requestPermission() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    // 最後の食事から指定時間後（＝次の食事の期限）に通知を1本だけスケジュール
    func scheduleNextMealReminder(from mealTime: Date, hours: Int = 6) {
        center.removePendingNotificationRequests(withIdentifiers: ["next-meal-reminder"])

        let fireDate = mealTime.addingTimeInterval(TimeInterval(hours * 3600))
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "そろそろ次の食事を"
        content.body = "最後の食事から\(hours)時間が経ちました"
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "next-meal-reminder", content: content, trigger: trigger
        )
        center.add(request)
    }

    // 毎日21時のリマインダー（アプリ起動時に1回だけ設定）
    func scheduleDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Fasting Tracker"
        content.body = "今日の記録をつけましたか？"
        content.sound = .default

        var comps = DateComponents()
        comps.hour = 21
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-reminder", content: content, trigger: trigger
        )
        center.add(request)
    }
}
