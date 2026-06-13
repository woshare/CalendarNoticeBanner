import EventKit
import AppKit

final class CalendarMonitor {
    private let eventStore = EKEventStore()
    private var timer: Timer?
    private var firedKeys: [String: Date] = [:]
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

    /// 找到最近的一个即将开始的事件并立即弹框，用于手动触发测试
    func forceCheckNow() {
        let now = Date()
        let lookahead = now.addingTimeInterval(24 * 60 * 60)
        let predicate = eventStore.predicateForEvents(withStart: now, end: lookahead, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)

        guard let ekEvent = ekEvents.min(by: { $0.startDate < $1.startDate }) else { return }

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

        let minutesBefore = max(1, Int(ekEvent.startDate.timeIntervalSince(now) / 60))
        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?(event, minutesBefore)
        }
    }

    func checkNow() {
        let now = Date()
        // Prune keys for events that have already started
        firedKeys = firedKeys.filter { $0.value > now }
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
                   firedKeys[key] == nil {
                    firedKeys[key] = event.startDate
                    DispatchQueue.main.async { [weak self] in
                        self?.onTrigger?(event, minutes)
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
