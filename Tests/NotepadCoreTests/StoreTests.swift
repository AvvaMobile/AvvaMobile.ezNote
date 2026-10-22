import XCTest
@testable import NotepadCore

final class StoreTests: TempDirTestCase {
    func testSessionRoundTrip() throws {
        let store = SessionStore(file: root.appending(path: "session.json"))
        let a = TabRecord(id: UUID(), kind: .temp(root.appending(path: "Not 1.txt")))
        let b = TabRecord(id: UUID(), kind: .file(URL(filePath: "/Users/x/Notlar.txt")))
        let session = Session(tabs: [a, b], activeTabID: b.id)
        try store.save(session)
        XCTAssertEqual(store.load(), session)
    }

    func testLoadReturnsNilWhenMissing() {
        XCTAssertNil(SessionStore(file: root.appending(path: "yok.json")).load())
    }

    func testLoadReturnsNilWhenCorrupt() throws {
        let file = root.appending(path: "session.json")
        try "{yarim".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertNil(SessionStore(file: file).load())
    }

    func testPendingSaveLoadRemove() throws {
        let store = PendingStore(dir: root)
        let id = UUID()
        try store.save("değişti 🙂", for: id)
        XCTAssertEqual(store.load(id), "değişti 🙂")
        store.remove(id)
        XCTAssertNil(store.load(id))
    }
}
