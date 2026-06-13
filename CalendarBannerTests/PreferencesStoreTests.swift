import XCTest
@testable import MeetBell

final class PreferencesStoreTests: XCTestCase {
    var store: PreferencesStore!

    override func setUp() {
        super.setUp()
        store = PreferencesStore(suiteName: "com.calendarbanner.tests")
        store.reset()
    }

    func test_defaultReminderMinutes() {
        XCTAssertEqual(store.reminderMinutes, [15, 5])
    }

    func test_saveAndLoadReminderMinutes() {
        store.reminderMinutes = [10, 3, 1]
        let loaded = PreferencesStore(suiteName: "com.calendarbanner.tests")
        XCTAssertEqual(loaded.reminderMinutes, [10, 3, 1])
    }

    func test_defaultBannerDuration() {
        XCTAssertEqual(store.bannerDuration, 5.0)
    }

    func test_defaultVerticalPosition() {
        XCTAssertEqual(store.verticalPosition, 0.35)
    }

    func test_defaultShowFields() {
        XCTAssertTrue(store.showTime)
        XCTAssertTrue(store.showCountdown)
        XCTAssertTrue(store.showLocation)
        XCTAssertTrue(store.showURL)
        XCTAssertTrue(store.showAttendeeCount)
    }

    func test_saveAndLoadShowTime() {
        store.showTime = false
        let loaded = PreferencesStore(suiteName: "com.calendarbanner.tests")
        XCTAssertFalse(loaded.showTime)
    }

    func test_defaultSnoozeDuration() {
        XCTAssertEqual(store.snoozeDuration, 5)
    }

    func test_saveAndLoadSnoozeDuration() {
        store.snoozeDuration = 10
        let loaded = PreferencesStore(suiteName: "com.calendarbanner.tests")
        XCTAssertEqual(loaded.snoozeDuration, 10)
    }
}
