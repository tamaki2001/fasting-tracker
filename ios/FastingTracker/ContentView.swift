import SwiftUI

struct ContentView: View {
    @Environment(FastingStore.self) private var store

    @State private var anchorDayOffset: Int = 0
    @State private var visibleDates: [Date] = []

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                visibleDates: visibleDates,
                onPrev:  { anchorDayOffset -= 1 },
                onNext:  { anchorDayOffset += 1 },
                onToday: { anchorDayOffset = 0 }
            )

            TimeGridView(
                anchorDayOffset: $anchorDayOffset,
                onVisibleDatesChange: { visibleDates = $0 }
            )

            LegendView()
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color(red: 0.051, green: 0.067, blue: 0.090))
        .task {
            await NotificationManager.shared.requestPermission()
            NotificationManager.shared.scheduleDailyReminder()
        }
    }
}
