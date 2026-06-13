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

    /// 找到时间上最近的事件（含已开始的）并立即弹框，用于手动触发测试
    func forceCheckNow() {
        let now = Date()
        let past = now.addingTimeInterval(-2 * 60 * 60)       // 往前看 2 小时
        let lookahead = now.addingTimeInterval(24 * 60 * 60)  // 往后看 24 小时
        let predicate = eventStore.predicateForEvents(withStart: past, end: lookahead, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)

        // 取 startDate 离现在最近的事件（无论已开始还是未开始）
        guard let ekEvent = ekEvents.min(by: {
            abs($0.startDate.timeIntervalSince(now)) < abs($1.startDate.timeIntervalSince(now))
        }) else { return }

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

        // 负数 = 已经过了多少分钟前开始；0 = 正在开始；正数 = 还有多少分钟
        let minutesBefore = Int(ekEvent.startDate.timeIntervalSince(now) / 60)
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
