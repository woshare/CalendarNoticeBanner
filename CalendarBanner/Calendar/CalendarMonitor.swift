import EventKit
import AppKit
import os

private let logger = Logger(subsystem: "com.meetbell", category: "CalendarMonitor")

final class CalendarMonitor {
    private let eventStore = EKEventStore()
    private var timer: Timer?
    private var firedKeys: [String: Date] = [:]
    private let preferences: PreferencesStore
    private var changeDebounceTask: DispatchWorkItem?

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarStoreChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        changeDebounceTask?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .EKEventStoreChanged, object: eventStore)
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

    @objc private func calendarStoreChanged() {
        changeDebounceTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.eventStore.refreshSourcesIfNecessary()
            self?.checkNow()
            logger.debug("calendarStoreChanged: 日历变动，已重新检查")
        }
        changeDebounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
    }

    /// 在前后一天范围内，找距当前时间最近且尚未结束的事件并立即弹框
    func forceCheckNow() {
        eventStore.refreshSourcesIfNecessary()
        let now = Date()
        let past = now.addingTimeInterval(-24 * 60 * 60)
        let lookahead = now.addingTimeInterval(24 * 60 * 60)
        let predicate = eventStore.predicateForEvents(withStart: past, end: lookahead, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)

        logger.debug("forceCheckNow: 找到 \(ekEvents.count) 个事件（±24h）")

        let notEnded = ekEvents.filter({ $0.endDate > now })
        logger.debug("forceCheckNow: 其中未结束 \(notEnded.count) 个")

        // 优先取未结束的最近事件；没有则兜底取整体最近事件
        let candidates = notEnded.isEmpty ? ekEvents : notEnded
        guard let ekEvent = candidates.min(by: {
            abs($0.startDate.timeIntervalSince(now)) < abs($1.startDate.timeIntervalSince(now))
        }) else {
            logger.info("forceCheckNow: ±24h 内没有任何事件，不弹框")
            return
        }

        logger.debug("forceCheckNow: 选中事件「\(ekEvent.title ?? "")」startDate=\(ekEvent.startDate) endDate=\(ekEvent.endDate)")

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

        let minutesBefore = Int(ekEvent.startDate.timeIntervalSince(now) / 60)
        logger.info("forceCheckNow: 准备弹框，minutesBefore=\(minutesBefore)")
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
                // key 含 startDate：事件改时间后 startDate 变化，key 随之变化，允许重新触发
                let key = Self.triggerKey(eventId: event.id, minutesBefore: minutes, startDate: event.startDate)

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

    static func triggerKey(eventId: String, minutesBefore: Int, startDate: Date) -> String {
        "\(eventId)__\(minutesBefore)min@\(Int(startDate.timeIntervalSinceReferenceDate))"
    }
}
