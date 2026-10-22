import XCTest
@testable import NotepadCore

final class WorkspaceFileTests: WorkspaceTestCase {
    private func makeFile(_ name: String, _ text: String) throws -> URL {
        let url = root.appending(path: name)
        try TextFile.write(text, to: url)
        return url
    }

    func testOpenAddsCleanFileTab() throws {
        let ws = try restored()
        let url = try makeFile("Notlar.txt", "merhaba")
        let doc = try ws.open(url)
        XCTAssertEqual(doc.kind, .file(url))
        XCTAssertEqual(doc.text, "merhaba")
        XCTAssertFalse(doc.isDirty)
        XCTAssertEqual(ws.activeID, doc.id)
        XCTAssertEqual(ws.tabs.count, 2)
    }

    func testOpenSameFileSelectsExistingTab() throws {
        let ws = try restored()
        let url = try makeFile("Notlar.txt", "merhaba")
        let doc = try ws.open(url)
        ws.select(ws.tabs[0].id)
        let again = try ws.open(url)
        XCTAssertEqual(again.id, doc.id)
        XCTAssertEqual(ws.tabs.count, 2)
        XCTAssertEqual(ws.activeID, doc.id)
    }

    func testOpenNonUTF8Throws() throws {
        let ws = try restored()
        let url = root.appending(path: "latin1.txt")
        try Data([0x47, 0xFC, 0x6C]).write(to: url)
        XCTAssertThrowsError(try ws.open(url))
        XCTAssertEqual(ws.tabs.count, 1)
    }

    func testEditingFileMarksDirtyAndFlushGoesToPending() throws {
        let ws = try restored()
        let url = try makeFile("Notlar.txt", "eski")
        let doc = try ws.open(url)
        ws.updateText(doc.id, "yeni")
        try ws.flush(doc.id)
        XCTAssertTrue(doc.isDirty)
        XCTAssertEqual(try TextFile.read(url), "eski")
        XCTAssertEqual(PendingStore(dir: paths.pendingDir).load(doc.id), "yeni")
    }

    func testSaveWritesFileAndClearsDirtyAndPending() throws {
        let ws = try restored()
        let url = try makeFile("Notlar.txt", "eski")
        let doc = try ws.open(url)
        ws.updateText(doc.id, "yeni")
        try ws.flush(doc.id)
        try ws.save(doc.id)
        XCTAssertEqual(try TextFile.read(url), "yeni")
        XCTAssertFalse(doc.isDirty)
        XCTAssertNil(PendingStore(dir: paths.pendingDir).load(doc.id))
    }

    func testSaveAsFromTempTrashesTempAndBecomesFile() throws {
        let ws = try restored()
        let doc = ws.tabs[0]
        let tempURL = doc.kind.url
        ws.updateText(doc.id, "kaydet beni")
        try ws.flush(doc.id)
        let target = root.appending(path: "Kayıt.txt")
        try ws.saveAs(doc.id, to: target)
        XCTAssertEqual(doc.kind, .file(target))
        XCTAssertFalse(doc.isDirty)
        XCTAssertEqual(try TextFile.read(target), "kaydet beni")
        XCTAssertEqual(trashed, [tempURL])
        XCTAssertEqual(SessionStore(file: paths.sessionFile).load()?.tabs.first?.kind, TabKind.file(target))
    }

    func testSaveAsOverAnotherOpenTabClosesThatTab() throws {
        let ws = try restored()
        let url = try makeFile("Notlar.txt", "eski")
        let other = try ws.open(url)
        let doc = ws.tabs[0]
        ws.updateText(doc.id, "yeni")
        try ws.saveAs(doc.id, to: url)
        XCTAssertNil(ws.tab(other.id))
        XCTAssertEqual(ws.tabs.map(\.id), [doc.id])
    }

    func testNeedsSavePanel() throws {
        let ws = try restored()
        let url = try makeFile("Notlar.txt", "x")
        let file = try ws.open(url)
        XCTAssertTrue(ws.needsSavePanel(ws.tabs[0].id))
        XCTAssertFalse(ws.needsSavePanel(file.id))
        try FileManager.default.removeItem(at: url)
        XCTAssertTrue(ws.needsSavePanel(file.id))
    }

    func testReloadChangedFilesUpdatesCleanTab() throws {
        let ws = try restored()
        let url = try makeFile("Notlar.txt", "eski")
        let doc = try ws.open(url)
        try TextFile.write("dışarıdan", to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: url.path)
        ws.reloadChangedFiles()
        XCTAssertEqual(doc.text, "dışarıdan")
        XCTAssertFalse(doc.isDirty)
    }

    func testReloadChangedFilesKeepsDirtyTab() throws {
        let ws = try restored()
        let url = try makeFile("Notlar.txt", "eski")
        let doc = try ws.open(url)
        ws.updateText(doc.id, "benim")
        try TextFile.write("dışarıdan", to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: url.path)
        ws.reloadChangedFiles()
        XCTAssertEqual(doc.text, "benim")
        XCTAssertTrue(doc.isDirty)
    }

    func testClosingDirtyFileWithDiscardRemovesPendingAndKeepsFile() throws {
        let ws = try restored()
        let url = try makeFile("Notlar.txt", "eski")
        let doc = try ws.open(url)
        ws.updateText(doc.id, "yeni")
        try ws.flush(doc.id)
        try ws.close(doc.id, discard: true)
        XCTAssertNil(PendingStore(dir: paths.pendingDir).load(doc.id))
        XCTAssertEqual(try TextFile.read(url), "eski")
        XCTAssertTrue(trashed.isEmpty)
    }
}
