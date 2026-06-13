import AppKit

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let url: URL?
    let attendeeCount: Int
    let calendarColor: NSColor

    func minutesUntilStart(from now: Date) -> Double {
        startDate.timeIntervalSince(now) / 60.0
    }

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}
