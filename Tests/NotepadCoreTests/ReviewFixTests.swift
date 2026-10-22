import XCTest
@testable import NotepadCore

/// Son gözden geçirmede bulunan not kaybı ve üstüne yazma senaryoları.
final class ReviewFixTests: WorkspaceTestCase {
    private func bumpModDate(_ url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: url.path)
    }

    func testSaveAsOntoOwnTempFileKeepsFile() throws {
        let ws = try restored()
        let doc = ws.tabs[0]
        let tempURL = doc.kind.url
        ws.updateText(doc.id, "kendi üstüne")
        try ws.saveAs(doc.id, to: tempURL)
        XCTAssertTrue(trashed.isEmpty)
        XCTAssertEqual(try TextFile.read(tempURL), "kendi üstüne")
        XCTAssertEqual(doc.kind, .file(tempURL))
    }

    func testFlushAllContinuesPastFailureAndSavesSession() throws {
        let ws = try restored()
        let broken = ws.tabs[0]
        let ok = try ws.newTab()
        let blocker = root.appending(path: "dosya")
        try TextFile.write("x", to: blocker)
        broken.kind = .temp(blocker.appending(path: "Not.txt"))
        ws.updateText(broken.id, "yazılamaz")
        ws.updateText(ok.id, "yazılır")

        XCTAssertThrowsError(try ws.flushAll())
        XCTAssertEqual(try TextFile.read(ok.kind.url), "yazılır")
        XCTAssertEqual(SessionStore(file: paths.sessionFile).load()?.tabs.count, 2)
    }

    func testFlushRecreatesDeletedNotesFolder() throws {
        let ws = try restored()
        let doc = ws.tabs[0]
        try FileManager.default.removeItem(at: paths.notesDir)
        ws.updateText(doc.id, "kurtar")
        try ws.flush(doc.id)
        XCTAssertEqual(try TextFile.read(doc.kind.url), "kurtar")
    }

    func testFlushAllDoesNotOverwriteUntouchedTemp() throws {
        let ws = try restored()
        let doc = ws.tabs[0]
        ws.updateText(doc.id, "bizim")
        try ws.flush(doc.id)
        try TextFile.write("TextEdit'ten", to: doc.kind.url)
        try ws.flushAll()
        XCTAssertEqual(try TextFile.read(doc.kind.url), "TextEdit'ten")
    }

    func testReloadChangedFilesUpdatesUntouchedTemp() throws {
        let ws = try restored()
        let doc = ws.tabs[0]
        ws.updateText(doc.id, "bizim")
        try ws.flush(doc.id)
        try TextFile.write("dışarıdan", to: doc.kind.url)
        try bumpModDate(doc.kind.url)
        ws.reloadChangedFiles()
        XCTAssertEqual(doc.text, "dışarıdan")
    }

    func testReloadChangedFilesKeepsUnflushedTemp() throws {
        let ws = try restored()
        let doc = ws.tabs[0]
        ws.updateText(doc.id, "yazıyorum")
        try TextFile.write("dışarıdan", to: doc.kind.url)
        try bumpModDate(doc.kind.url)
        ws.reloadChangedFiles()
        XCTAssertEqual(doc.text, "yazıyorum")
    }
}
