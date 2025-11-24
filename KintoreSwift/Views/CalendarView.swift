//CalendarView.swift

import SwiftUI
import FSCalendar

struct CalendarView: UIViewRepresentable {
    @Binding var selectedDate: Date
    var markedDates: [Date] = []

    func makeUIView(context: Context) -> FSCalendar {
        let calendar = FSCalendar()
        calendar.delegate = context.coordinator
        calendar.dataSource = context.coordinator

        calendar.appearance.headerDateFormat = "MMMM yyyy"
        calendar.appearance.todayColor = .systemBlue
        calendar.appearance.selectionColor = .systemGray
        calendar.appearance.titleTodayColor = .white
        calendar.scrollDirection = .horizontal
        calendar.scope = .month
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.appearance.borderRadius = 0.4
        calendar.appearance.eventDefaultColor = .clear
        calendar.appearance.eventSelectionColor = .clear
        return calendar
    }

    func updateUIView(_ uiView: FSCalendar, context: Context) {
        // ✅ 日付を正規化（時刻を0:00に）
        let normalized = markedDates.map { Calendar.current.startOfDay(for: $0) }
        context.coordinator.updateMarkedKeys(from: normalized)
        uiView.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        let c = Coordinator(self)
        c.updateMarkedKeys(from: markedDates.map { Calendar.current.startOfDay(for: $0) })
        return c
    }

    class Coordinator: NSObject, FSCalendarDelegate, FSCalendarDataSource, FSCalendarDelegateAppearance {
        private let parent: CalendarView
        private var markedKeys: Set<String> = []

        private lazy var keyFormatter: DateFormatter = {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "ja_JP")
            f.timeZone = .current
            f.dateFormat = "yyyy-MM-dd"
            return f
        }()

        init(_ parent: CalendarView) {
            self.parent = parent
        }

        func updateMarkedKeys(from dates: [Date]) {
            markedKeys = Set(dates.map { keyFormatter.string(from: $0) })
        }

        func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
            parent.selectedDate = date
        }

        func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int { 0 }

        // ✅ 記録がある日は淡い青で塗る
        func calendar(_ calendar: FSCalendar,
                      appearance: FSCalendarAppearance,
                      fillDefaultColorFor date: Date) -> UIColor? {
            let key = keyFormatter.string(from: date)
            return markedKeys.contains(key) ? UIColor.systemBlue.withAlphaComponent(0.4) : nil
        }

        func calendar(_ calendar: FSCalendar,
                      appearance: FSCalendarAppearance,
                      titleDefaultColorFor date: Date) -> UIColor? {
            let key = keyFormatter.string(from: date)
            return markedKeys.contains(key) ? UIColor.systemBlue : UIColor.label
        }
    }
}
