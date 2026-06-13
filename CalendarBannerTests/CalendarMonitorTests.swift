import XCTest
@testable import CalendarBanner

final class CalendarMonitorTests: XCTestCase {

    func test_shouldTrigger_returnsTrue_whenWithinWindow() {
        let now = Date()
        let triggerTime = now
        let result = CalendarMonitor.isWithinTriggerWindow(
            now: now,
            triggerTime: triggerTime
        )
        XCTAssertTrue(result)
    }

    func test_shouldTrigger_returnsTrue_when25SecondsEarly() {
        let now = Date()
        let triggerTime = now.addingTimeInterval(25)
        let result = CalendarMonitor.isWithinTriggerWindow(
            now: now,
            triggerTime: triggerTime
        )
        XCTAssertTrue(result)
    }

    func test_shouldTrigger_returnsFalse_when40SecondsEarly() {
        let now = Date()
        let triggerTime = now.addingTimeInterval(40)
        let result = CalendarMonitor.isWithinTriggerWindow(
            now: now,
            triggerTime: triggerTime
        )
        XCTAssertFalse(result)
    }

    func test_shouldTrigger_returnsFalse_when40SecondsLate() {
        let now = Date()
        let triggerTime = now.addingTimeInterval(-40)
        let result = CalendarMonitor.isWithinTriggerWindow(
            now: now,
            triggerTime: triggerTime
        )
        XCTAssertFalse(result)
    }

    func test_triggerKey_isUniquePerEventAndMinute() {
        let key1 = CalendarMonitor.triggerKey(eventId: "evt-1", minutesBefore: 5)
        let key2 = CalendarMonitor.triggerKey(eventId: "evt-1", minutesBefore: 15)
        let key3 = CalendarMonitor.triggerKey(eventId: "evt-2", minutesBefore: 5)
        XCTAssertNotEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }
}
