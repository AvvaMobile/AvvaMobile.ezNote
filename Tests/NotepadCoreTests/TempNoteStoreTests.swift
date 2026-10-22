import XCTest
@testable import NotepadCore

final class TempNoteStoreTests: TempDirTestCase {
    /// 2026-10-22 14:30:05, yerel saat.
    private let now: Date = {
        var c = DateComponents()
        (c.year, c.month, c.day, c.hour, c.minute, c.second) = (2026, 10, 22, 14, 30, 5)
        return Calendar.current.date(from: c)!
    }()

    func testRoundTripKeepsTurkishAndEmoji() throws {
        let url = root.appending(path: "t.txt")
        let text = "Çğışöü İ 🙂\n"
        try TextFile.write(text, to: url)
        XCTAssertEqual(try TextFile.read(url), text)
        XCTAssertEqual(try Data(contentsOf: url), text.data(using: .utf8))
    }

    func testReadThrowsNotUTF8ForLatin1() throws {
        let url = root.appending(path: "latin1.txt")
        try Data([0x47, 0xFC, 0x6C]).write(to: url)
        XCTAssertThrowsError(try TextFile.read(url)) { error in
            XCTAssertEqual(error as? TextFileError, .notUTF8)
        }
    }

    func testCreateUsesDateNameAndWritesEmptyFile() throws {
        let url = try TempNoteStore(dir: root).create(now: now)
        XCTAssertEqual(url.lastPathComponent, "Not 2026-10-22 14.30.05.txt")
        XCTAssertTrue(exists(url))
        XCTAssertEqual(try Data(contentsOf: url).count, 0)
    }

    func testCreateAddsSuffixOnCollision() throws {
        let store = TempNoteStore(dir: root)
        _ = try store.create(now: now)
        let second = try store.create(now: now)
        XCTAssertEqual(second.lastPathComponent, "Not 2026-10-22 14.30.05 2.txt")
    }

    func testIsTempName() {
        let store = TempNoteStore(dir: root)
        XCTAssertTrue(store.isTempName("Not 2026-10-22 14.30.05.txt"))
        XCTAssertTrue(store.isTempName("Not 2026-10-22 14.30.05 2.txt"))
        XCTAssertFalse(store.isTempName("Alisveris.txt"))
        XCTAssertFalse(store.isTempName("Not.txt"))
    }

    func testOrphansExcludesKnownAndNonTempFiles() throws {
        let store = TempNoteStore(dir: root)
        let a = try store.create(now: now)
        let b = try store.create(now: now)
        try "x".write(to: root.appending(path: "Alisveris.txt"), atomically: true, encoding: .utf8)
        XCTAssertEqual(store.orphans(excluding: [a]).map(\.lastPathComponent), [b.lastPathComponent])
    }

    func testMoveToTrashCallsInjectedTrash() throws {
        var trashed: [URL] = []
        let store = TempNoteStore(dir: root, trash: { trashed.append($0) })
        let url = try store.create(now: now)
        try store.moveToTrash(url)
        XCTAssertEqual(trashed, [url])
    }

    func testDeletePermanentlyRemovesFile() throws {
        let store = TempNoteStore(dir: root)
        let url = try store.create(now: now)
        try store.deletePermanently(url)
        XCTAssertFalse(exists(url))
    }
}
