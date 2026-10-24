import AppKit
import XCTest
@testable import Notepad
@testable import NotepadCore

final class MainMenuTests: XCTestCase {
    func testBuyMeACoffeeSitsRightUnderAbout() throws {
        let appMenu = try XCTUnwrap(MainMenu.build().items.first?.submenu)
        let titles = appMenu.items.map(\.title)
        let about = try XCTUnwrap(titles.firstIndex(of: "About \(AppInfo.name)"))
        XCTAssertEqual(titles[about + 1], "Buy Me a Coffee…")
        XCTAssertEqual(appMenu.items[about + 1].action, #selector(NotepadActions.buyMeACoffeeAction(_:)))
    }

    func testAppIsNamedEzNote() throws {
        XCTAssertEqual(AppInfo.name, "ezNote")
        let appMenu = try XCTUnwrap(MainMenu.build().items.first?.submenu)
        XCTAssertTrue(appMenu.items.map(\.title).contains("Quit ezNote"))
    }

    func testCoffeeLink() {
        XCTAssertEqual(AppInfo.coffeeURL.absoluteString, "https://buymeacoffee.com/muratyilmaz")
    }
}
