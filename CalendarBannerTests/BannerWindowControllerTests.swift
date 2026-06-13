import XCTest
@testable import MeetBell

final class BannerWindowControllerTests: XCTestCase {

    func test_bannerWidth_clampedBetween400and600() {
        XCTAssertEqual(BannerWindowController.bannerWidth(forScreenWidth: 800), 400)
        XCTAssertEqual(BannerWindowController.bannerWidth(forScreenWidth: 1200), 600)
        XCTAssertEqual(BannerWindowController.bannerWidth(forScreenWidth: 1000), 500)
    }

    func test_bannerY_calculatedFromVerticalPosition() {
        let y = BannerWindowController.bannerY(screenHeight: 900, verticalPosition: 0.35)
        XCTAssertEqual(y, 315, accuracy: 0.1)
    }

    func test_multipleOffsets_stagedVertically() {
        let offsets = BannerWindowController.verticalOffsets(forCount: 3, bannerHeight: 64, spacing: 16)
        XCTAssertEqual(offsets.count, 3)
        XCTAssertEqual(offsets[1] - offsets[0], 80, accuracy: 0.1) // 64 + 16 = 80
    }
}
