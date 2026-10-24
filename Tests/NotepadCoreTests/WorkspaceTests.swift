import XCTest
@testable import NotepadCore

final class WorkspaceTests: WorkspaceTestCase {
    func testFreshRestoreOpensOneEmptyTempTab() throws {
        let ws = try restored()
        XCTAssertEqual(ws.tabs.count, 1)
        XCTAssertTrue(ws.tabs[0].kind.isTemp)
        XCTAssertEqual(ws.tabs[0].kind.url.deletingLastPathComponent().canonical, paths.notesDir.canonical)
        XCTAssertTrue(exists(ws.tabs[0].kind.url))
        XCTAssertEqual(ws.active?.title, "Untitled 1")
    }

    func testNewTabIsAppendedAndSelected() throws {
        let ws = try restored()
        let doc = try ws.newTab()
        XCTAssertEqual(ws.tabs.last?.id, doc.id)
        XCTAssertEqual(ws.activeID, doc.id)
    }

    func testNewTabGetsLowestFreeUntitledNumber() throws {
        let ws = try restored()
        let second = try ws.newTab()
        try ws.newTab()
        try ws.close(second.id, discard: true)
        XCTAssertEqual(try ws.newTab().title, "Untitled 2")
    }

    func testFlushWritesTempFile() throws {
        let ws = try restored()
        let doc = ws.tabs[0]
        ws.updateText(doc.id, "deneme")
        try ws.flush(doc.id)
        XCTAssertEqual(try TextFile.read(doc.kind.url), "deneme")
    }

    func testClosingBlankTempDeletesFileWithoutTrash() throws {
        let ws = try restored()
        let doc = try ws.newTab()
        ws.updateText(doc.id, " \n ")
        try ws.flush(doc.id)
        try ws.close(doc.id, discard: true)
        XCTAssertFalse(exists(doc.kind.url))
        XCTAssertTrue(trashed.isEmpty)
    }

    func testClosingFilledTempWithDiscardTrashes() throws {
        let ws = try restored()
        let doc = try ws.newTab()
        ws.updateText(doc.id, "not")
        try ws.flush(doc.id)
        try ws.close(doc.id, discard: true)
        XCTAssertEqual(trashed, [doc.kind.url])
        XCTAssertEqual(ws.tabs.count, 1)
    }

    func testClosingActiveSelectsRightNeighbor() throws {
        let ws = try restored()
        let first = ws.tabs[0]
        let second = try ws.newTab()
        let third = try ws.newTab()
        ws.select(second.id)
        try ws.close(second.id, discard: true)
        XCTAssertEqual(ws.activeID, third.id)
        try ws.close(third.id, discard: true)
        XCTAssertEqual(ws.activeID, first.id)
    }

    func testClosingLastTabOpensNewEmptyTab() throws {
        let ws = try restored()
        let only = ws.tabs[0]
        try ws.close(only.id, discard: true)
        XCTAssertEqual(ws.tabs.count, 1)
        XCTAssertNotEqual(ws.tabs[0].id, only.id)
        XCTAssertEqual(ws.activeID, ws.tabs[0].id)
    }

    func testRestoreReopensTabsInOrderWithActive() throws {
        let ws = try restored()
        ws.updateText(ws.tabs[0].id, "bir")
        ws.updateText(try ws.newTab().id, "iki")
        ws.updateText(try ws.newTab().id, "üç")
        ws.select(ws.tabs[1].id)
        try ws.flushAll()

        let again = try restored()
        XCTAssertEqual(again.tabs.map(\.text), ["bir", "iki", "üç"])
        XCTAssertEqual(again.tabs.map(\.id), ws.tabs.map(\.id))
        XCTAssertEqual(again.activeID, ws.tabs[1].id)
    }

    func testRestoreSkipsMissingTempFile() throws {
        let ws = try restored()
        ws.updateText(ws.tabs[0].id, "kalsın")
        let gone = try ws.newTab()
        try ws.flushAll()
        try FileManager.default.removeItem(at: gone.kind.url)

        let again = try restored()
        XCTAssertEqual(again.tabs.map(\.text), ["kalsın"])
    }

    func testRestoreAdoptsOrphanTempFiles() throws {
        let ws = try restored()
        ws.updateText(ws.tabs[0].id, "oturumda")
        try ws.flushAll()
        let orphan = try TempNoteStore(dir: paths.notesDir).create(now: Date(timeIntervalSince1970: 1_900_000_000))
        try TextFile.write("sahipsiz", to: orphan)

        let again = try restored()
        XCTAssertEqual(again.tabs.map(\.text), ["oturumda", "sahipsiz"])
        XCTAssertTrue(again.tabs[1].kind.isTemp)
    }

    func testRestoreDoesNotAdoptFileTabInNotesDir() throws {
        let inNotes = paths.notesDir.appending(path: "Note 2026-10-22 14.30.05.txt")
        try paths.ensureDirectories()
        try TextFile.write("dosya", to: inNotes)
        let id = UUID()
        try SessionStore(file: paths.sessionFile).save(Session(tabs: [TabRecord(id: id, kind: .file(inNotes))], activeTabID: id))

        let ws = try restored()
        XCTAssertEqual(ws.tabs.count, 1)
        XCTAssertEqual(ws.tabs[0].kind, .file(inNotes))
    }

    func testRestoreSurvivesCorruptSession() throws {
        try paths.ensureDirectories()
        let note = try TempNoteStore(dir: paths.notesDir).create(now: Date())
        try TextFile.write("kurtarıldı", to: note)
        try "{bozuk".write(to: paths.sessionFile, atomically: true, encoding: .utf8)

        let ws = try restored()
        XCTAssertEqual(ws.tabs.map(\.text), ["kurtarıldı"])
    }

    func testRestoreDirtyFileFromPending() throws {
        let file = root.appending(path: "Notlar.txt")
        try TextFile.write("eski", to: file)
        let id = UUID()
        try paths.ensureDirectories()
        try SessionStore(file: paths.sessionFile).save(Session(tabs: [TabRecord(id: id, kind: .file(file))], activeTabID: id))
        try PendingStore(dir: paths.pendingDir).save("yeni", for: id)

        let ws = try restored()
        XCTAssertEqual(ws.tabs[0].text, "yeni")
        XCTAssertTrue(ws.tabs[0].isDirty)
        XCTAssertEqual(try TextFile.read(file), "eski")
    }

    func testRestoreMissingFileWithPendingStillOpens() throws {
        let file = root.appending(path: "Silindi.txt")
        let id = UUID()
        try paths.ensureDirectories()
        try SessionStore(file: paths.sessionFile).save(Session(tabs: [TabRecord(id: id, kind: .file(file))], activeTabID: id))
        try PendingStore(dir: paths.pendingDir).save("kurtar", for: id)

        let ws = try restored()
        XCTAssertEqual(ws.tabs.map(\.text), ["kurtar"])
        XCTAssertTrue(ws.tabs[0].isDirty)
    }

    func testRestoreMissingFileWithoutPendingIsSkipped() throws {
        let id = UUID()
        try paths.ensureDirectories()
        try SessionStore(file: paths.sessionFile).save(Session(tabs: [TabRecord(id: id, kind: .file(root.appending(path: "Yok.txt")))], activeTabID: id))

        let ws = try restored()
        XCTAssertEqual(ws.tabs.count, 1)
        XCTAssertTrue(ws.tabs[0].kind.isTemp)
    }

    func testSessionIsPersistedAfterNewTab() throws {
        let ws = try restored()
        try ws.newTab()
        XCTAssertEqual(SessionStore(file: paths.sessionFile).load()?.tabs.count, 2)
    }

    func testOnChangeFiresOnNewTab() throws {
        let ws = try restored()
        var calls = 0
        ws.onChange = { calls += 1 }
        try ws.newTab()
        XCTAssertGreaterThan(calls, 0)
    }
}
