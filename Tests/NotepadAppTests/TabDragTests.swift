import XCTest
@testable import Notepad

/// Sürüklenen sekmenin ortası komşu sekmenin yarısını geçince yer değiştirir.
final class TabDragTests: XCTestCase {
    func testCenterOfSlotStaysInThatSlot() {
        let mid = TabBarView.slotOrigin(2) + TabBarView.tabWidth / 2
        XCTAssertEqual(TabBarView.dropIndex(centerX: mid, count: 4), 2)
    }

    func testCrossingSlotBoundaryMovesToNextSlot() {
        let boundary = TabBarView.slotOrigin(1)
        XCTAssertEqual(TabBarView.dropIndex(centerX: boundary - 1, count: 4), 0)
        XCTAssertEqual(TabBarView.dropIndex(centerX: boundary + 1, count: 4), 1)
    }

    func testDropIndexIsClamped() {
        XCTAssertEqual(TabBarView.dropIndex(centerX: -500, count: 3), 0)
        XCTAssertEqual(TabBarView.dropIndex(centerX: 5000, count: 3), 2)
    }
}
