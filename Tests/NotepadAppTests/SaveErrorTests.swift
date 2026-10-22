import AppKit
import XCTest
@testable import Notepad
@testable import NotepadCore

/// Otomatik kaydetme ve çıkışta yazma hatası sessiz kalmamalı.
final class SaveErrorTests: XCTestCase {
    private var root: URL!
    private var controller: MainWindowController!
    private var workspace: Workspace!
    private var shown: [Error] = []

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "NotepadAppTests-\(UUID().uuidString)")
        workspace = Workspace(paths: Paths(appName: "Test", documents: root.appending(path: "Docs"), appSupport: root.appending(path: "Sup")))
        try workspace.restore()
        controller = MainWindowController(workspace: workspace, font: FontSettings(family: nil, size: 14))
        controller.saveErrorPresenter = { [unowned self] in shown.append($0) }
    }

    override func tearDownWithError() throws {
        controller.window?.delegate = nil
        controller.close()
        try? FileManager.default.removeItem(at: root)
    }

    /// Sekmenin temp dosyasını, üst klasörü aslında bir dosya olan bir yola bağlar; yazma başarısız olur.
    private func breakTab(_ doc: TabDocument) throws -> TabKind {
        let blocker = root.appending(path: "dosya")
        try TextFile.write("x", to: blocker)
        let original = doc.kind
        doc.kind = .temp(blocker.appending(path: "Not.txt"))
        return original
    }

    func testAutosaveFailureIsShownOnceUntilASaveSucceeds() throws {
        let doc = workspace.tabs[0]
        let original = try breakTab(doc)
        workspace.updateText(doc.id, "a")
        controller.flushReporting(doc.id)
        workspace.updateText(doc.id, "ab")
        controller.flushReporting(doc.id)
        XCTAssertEqual(shown.count, 1)

        doc.kind = original
        controller.flushReporting(doc.id)
        XCTAssertEqual(shown.count, 1)

        _ = try breakTab(doc)
        workspace.updateText(doc.id, "abc")
        controller.flushReporting(doc.id)
        XCTAssertEqual(shown.count, 2)
    }

    func testFlushAllReturnsErrorWhenATabCannotBeWritten() throws {
        let doc = workspace.tabs[0]
        _ = try breakTab(doc)
        workspace.updateText(doc.id, "kaybolmasın")
        XCTAssertNotNil(controller.flushAll())
    }

    func testFlushAllReturnsNilWhenEverythingIsWritten() {
        workspace.updateText(workspace.tabs[0].id, "tamam")
        XCTAssertNil(controller.flushAll())
    }
}
