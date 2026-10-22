import XCTest
@testable import NotepadCore

final class LogicTests: XCTestCase {
    private let temp = TabKind.temp(URL(filePath: "/tmp/Not.txt"))
    private let file = TabKind.file(URL(filePath: "/x/y/Notlar.txt"))

    func testTitleTempFirstLine() {
        XCTAssertEqual(TabTitle.make(text: "Market listesi\nsüt", kind: temp, untitledNumber: 1), "Market listesi")
    }

    func testTitleTempTrimsFirstLine() {
        XCTAssertEqual(TabTitle.make(text: "   Toplantı  \nx", kind: temp, untitledNumber: 1), "Toplantı")
    }

    func testTitleTempTruncates() {
        let line = String(repeating: "a", count: 40)
        XCTAssertEqual(TabTitle.make(text: line, kind: temp, untitledNumber: 1), String(repeating: "a", count: 30) + "…")
    }

    func testTitleTempEmptyUsesUntitled() {
        XCTAssertEqual(TabTitle.make(text: "\n\nabc", kind: temp, untitledNumber: 2), "Adsız 2")
    }

    func testTitleFileUsesFileName() {
        XCTAssertEqual(TabTitle.make(text: "içerik", kind: file, untitledNumber: 1), "Notlar.txt")
    }

    func testCloseBlankTempIsSilent() {
        XCTAssertEqual(closeAction(kind: temp, text: "  \n\t\n", isDirty: false), .closeSilently)
    }

    func testCloseFilledTempAsks() {
        XCTAssertEqual(closeAction(kind: temp, text: "a", isDirty: false), .askTemp)
    }

    func testCloseDirtyFileAsks() {
        XCTAssertEqual(closeAction(kind: file, text: "a", isDirty: true), .askFile)
    }

    func testCloseCleanFileIsSilent() {
        XCTAssertEqual(closeAction(kind: file, text: "a", isDirty: false), .closeSilently)
    }

    func testZoomClampsAtLimits() {
        XCTAssertEqual(FontSettings(family: nil, size: 72).zoomedIn().size, 72)
        XCTAssertEqual(FontSettings(family: nil, size: 8).zoomedOut().size, 8)
        XCTAssertEqual(FontSettings(family: nil, size: 14).zoomedIn().size, 15)
        XCTAssertEqual(FontSettings(family: nil, size: 14).zoomedOut().size, 13)
    }

    func testFontStoreRoundTripAndDefault() throws {
        let suite = "NotepadTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FontSettingsStore(defaults: defaults)

        XCTAssertEqual(store.load(), FontSettings(family: nil, size: 14))
        store.save(FontSettings(family: "Menlo", size: 18))
        XCTAssertEqual(store.load(), FontSettings(family: "Menlo", size: 18))
    }
}
