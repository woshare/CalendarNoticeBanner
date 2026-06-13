import EventKit
import AppKit

final class CalendarMonitor {
    private let eventStore = EKEventStore()
    private var timer: Timer?
    private var firedKeys = Set<String>()
    private let preferences: PreferencesStore

    var onTrigger: ((CalendarEvent, Int) -> Void)?
    var onPermissionDenied: (() -> Void)?

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    func start() {
        requestAccessIfNeeded()
        checkNow()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkNow()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func requestAccessIfNeeded() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                if !granted {
                    DispatchQueue.main.async { self?.onPermissionDenied?() }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                if !granted {
                    DispatchQueue.main.async { self?.onPermissionDenied?() }
                }
            }
        }
    }

    @objc private func handleWake() {
        checkNow()
    }

    func checkNow() {
        let now = Date()
        let lookahead = now.addingTimeInterval(90 * 60)
        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: lookahead,
            calendars: nil
        )
        let ekEvents = eventStore.events(matching: predicate)

        for ekEvent in ekEvents {
            let event = CalendarEvent(
                id: ekEvent.eventIdentifier,
                title: ekEvent.title.isEmpty ? "无标题会议" : ekEvent.title,
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                location: ekEvent.location,
                url: ekEvent.url,
                attendeeCount: ekEvent.attendees?.count ?? 0,
                calendarColor: NSColor(cgColor: ekEvent.calendar.cgColor) ?? .systemBlue
            )

            for minutes in preferences.reminderMinutes {
                let triggerTime = event.startDate.addingTimeInterval(Double(-minutes) * 60)
                let key = Self.triggerKey(eventId: event.id, minutesBefore: minutes)

                if Self.isWithinTriggerWindow(now: now, triggerTime: triggerTime),
                   !firedKeys.contains(key) {
                    firedKeys.insert(key)
                    DispatchQueue.main.async {
                        self.onTrigger?(event, minutes)
                    }
                }
            }
        }
    }

    static func isWithinTriggerWindow(now: Date, triggerTime: Date) -> Bool {
        abs(now.timeIntervalSince(triggerTime)) <= 30
    }

    static func triggerKey(eventId: String, minutesBefore: Int) -> String {
        "\(eventId)__\(minutesBefore)min"
    }
}
