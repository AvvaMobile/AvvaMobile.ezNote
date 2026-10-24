import XCTest
@testable import NotepadCore

final class PathsTests: TempDirTestCase {
    private var docs: URL { root.appending(path: "Docs") }
    private var sup: URL { root.appending(path: "Sup") }

    func testPathsUseAppNameUnderDocumentsAndSupport() {
        let p = Paths(appName: "Notepad#", documents: docs, appSupport: sup)
        XCTAssertEqual(p.notesDir, root.appending(path: "Docs/Notepad#"))
        XCTAssertEqual(p.supportDir, root.appending(path: "Sup/Notepad#"))
        XCTAssertEqual(p.sessionFile, root.appending(path: "Sup/Notepad#/session.json"))
        XCTAssertEqual(p.pendingDir, root.appending(path: "Sup/Notepad#/pending"))
    }

    func testEnsureDirectoriesCreatesAllThree() throws {
        let p = Paths(appName: "Notepad#", documents: docs, appSupport: sup)
        try p.ensureDirectories()
        XCTAssertTrue(exists(p.notesDir))
        XCTAssertTrue(exists(p.supportDir))
        XCTAssertTrue(exists(p.pendingDir))
    }

    func testMigrateMovesBothFoldersToNewName() throws {
        let old = Paths(appName: "Eski", documents: docs, appSupport: sup)
        try old.ensureDirectories()
        try "a".write(to: old.notesDir.appending(path: "a.txt"), atomically: true, encoding: .utf8)

        try FolderMigration.migrate(documents: docs, appSupport: sup, from: "Eski", to: "Yeni")

        XCTAssertTrue(exists(docs.appending(path: "Yeni/a.txt")))
        XCTAssertTrue(exists(sup.appending(path: "Yeni")))
        XCTAssertFalse(exists(docs.appending(path: "Eski")))
        XCTAssertFalse(exists(sup.appending(path: "Eski")))
    }

    func testMigrateDoesNothingWhenNewFolderAlreadyExists() throws {
        try Paths(appName: "Eski", documents: docs, appSupport: sup).ensureDirectories()
        try Paths(appName: "Yeni", documents: docs, appSupport: sup).ensureDirectories()

        try FolderMigration.migrate(documents: docs, appSupport: sup, from: "Eski", to: "Yeni")

        XCTAssertTrue(exists(docs.appending(path: "Eski")))
        XCTAssertTrue(exists(sup.appending(path: "Eski")))
    }

    func testMigrateDoesNothingWhenOldFolderMissing() throws {
        XCTAssertNoThrow(try FolderMigration.migrate(documents: docs, appSupport: sup, from: "Eski", to: "Yeni"))
        XCTAssertFalse(exists(docs.appending(path: "Yeni")))
    }
}

final class RenameRestoreTests: WorkspaceTestCase {
    /// Ad değişince sekmeler aynı sırayla, aynı aktif sekmeyle, notlar klasörüne kaydedilmiş dosyalar dahil geri gelmeli.
    func testRenameKeepsTabOrderActiveTabAndFilesInNotesFolder() throws {
        let docs = root.appending(path: "Docs"), sup = root.appending(path: "Sup")
        let old = Workspace(paths: Paths(appName: "Eski", documents: docs, appSupport: sup))
        try old.restore()
        old.updateText(old.tabs[0].id, "bir")
        let second = try old.newTab()
        old.updateText(second.id, "iki")
        let saved = try old.newTab()
        old.updateText(saved.id, "kayıtlı")
        try old.saveAs(saved.id, to: docs.appending(path: "Eski/Liste.txt"))
        old.select(second.id)
        try old.flushAll()

        try FolderMigration.migrate(documents: docs, appSupport: sup, from: "Eski", to: "Yeni")

        let renamed = Workspace(paths: Paths(appName: "Yeni", documents: docs, appSupport: sup))
        try renamed.restore()
        XCTAssertEqual(renamed.tabs.map(\.text), ["bir", "iki", "kayıtlı"])
        XCTAssertEqual(renamed.activeID, second.id)
        XCTAssertEqual(renamed.tabs[2].kind, .file(docs.appending(path: "Yeni/Liste.txt")))
    }
}
