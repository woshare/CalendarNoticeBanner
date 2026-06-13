import XCTest
@testable import CalendarBanner

final class CalendarEventTests: XCTestCase {

    func test_init_storesAllFields() {
        let start = Date()
        let end = start.addingTimeInterval(3600)
        let url = URL(string: "https://zoom.us/j/123")!

        let event = CalendarEvent(
            id: "evt-001",
            title: "产品评审会",
            startDate: start,
            endDate: end,
            location: "腾讯会议 Room 123",
            url: url,
            attendeeCount: 8,
            calendarColor: .systemBlue
        )

        XCTAssertEqual(event.id, "evt-001")
        XCTAssertEqual(event.title, "产品评审会")
        XCTAssertEqual(event.startDate, start)
        XCTAssertEqual(event.endDate, end)
        XCTAssertEqual(event.location, "腾讯会议 Room 123")
        XCTAssertEqual(event.url, url)
        XCTAssertEqual(event.attendeeCount, 8)
    }

    func test_init_allowsNilLocationAndUrl() {
        let event = CalendarEvent(
            id: "evt-002",
            title: "无标题会议",
            startDate: Date(),
            endDate: Date(),
            location: nil,
            url: nil,
            attendeeCount: 0,
            calendarColor: .systemGray
        )
        XCTAssertNil(event.location)
        XCTAssertNil(event.url)
    }

    func test_minutesUntilStart_returnsCorrectValue() {
        let start = Date().addingTimeInterval(300) // 5分钟后
        let event = CalendarEvent(
            id: "e", title: "t", startDate: start, endDate: start,
            location: nil, url: nil, attendeeCount: 0, calendarColor: .black
        )
        let minutes = event.minutesUntilStart(from: Date())
        XCTAssertEqual(minutes, 5, accuracy: 0.1)
    }
}
