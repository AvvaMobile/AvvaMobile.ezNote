import AppKit
import XCTest
@testable import Notepad

/// Sekme çubuğunun boş yerine çift tıklayınca yeni sekme açılır; sekmeye ya da tek tıklamaya açılmaz.
final class TabBarDoubleClickTests: XCTestCase {
    private var bar: TabBarView!
    private var newCount = 0

    override func setUp() {
        bar = TabBarView(frame: NSRect(x: 0, y: 0, width: 800, height: 32))
        bar.onNew = { [unowned self] in newCount += 1 }
        let id = UUID()
        bar.update(items: [.init(id: id, title: "Notes", isDirty: false)], activeID: id)
        bar.layoutSubtreeIfNeeded()
    }

    private func click(at x: CGFloat, count: Int) throws {
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: count, pressure: 1
        ))
        try XCTUnwrap(bar.hitTest(NSPoint(x: x, y: 16))).mouseDown(with: event)
    }

    func testDoubleClickRightOfTabsOpensNewTab() throws {
        try click(at: 600, count: 2)
        XCTAssertEqual(newCount, 1)
    }

    func testDoubleClickBetweenTabAndPlusOpensNewTab() throws {
        try click(at: TabBarView.slotOrigin(1) + 1, count: 2)
        XCTAssertEqual(newCount, 1)
    }

    func testSingleClickOnEmptyAreaDoesNothing() throws {
        try click(at: 600, count: 1)
        XCTAssertEqual(newCount, 0)
    }

    func testDoubleClickOnTabDoesNotOpenNewTab() throws {
        try click(at: TabBarView.slotOrigin(0) + 20, count: 2)
        XCTAssertEqual(newCount, 0)
    }
}
