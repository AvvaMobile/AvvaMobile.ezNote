import AppKit
import XCTest
@testable import Notepad
@testable import NotepadCore

/// Finder'dan pencereye ya da Dock ikonuna bırakılan .txt ve .json dosyaları sekmede açılır; diğerleri yok sayılır.
final class FileDropTests: XCTestCase {
    private var root: URL!
    private var controller: MainWindowController!
    private var workspace: Workspace!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "NotepadAppTests-\(UUID().uuidString)")
        workspace = Workspace(paths: Paths(appName: "Test", documents: root.appending(path: "Docs"), appSupport: root.appending(path: "Sup")))
        try workspace.restore()
        controller = MainWindowController(workspace: workspace, font: FontSettings(family: nil, size: 14))
    }

    override func tearDownWithError() throws {
        controller.window?.delegate = nil
        controller.close()
        try? FileManager.default.removeItem(at: root)
    }

    private func file(_ name: String) throws -> URL {
        let url = root.appending(path: name)
        try TextFile.write("içerik", to: url)
        return url
    }

    private var openURLs: [URL] {
        workspace.tabs.filter { !$0.kind.isTemp }.map(\.kind.url.canonical)
    }

    func testOnlyTxtAndJsonFilesAreTakenFromPasteboard() throws {
        let txt = try file("a.txt"), upper = try file("B.TXT"), json = try file("d.json"), md = try file("c.md")
        let board = NSPasteboard(name: .init("FileDropTests-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        board.clearContents()
        board.writeObjects([txt, upper, json, md] as [NSURL])
        XCTAssertEqual(FileDrop.textFiles(on: board).map(\.canonical), [txt.canonical, upper.canonical, json.canonical])
    }

    func testOpenFilesOpensOnlyTxtAndJson() throws {
        let txt = try file("a.txt"), json = try file("D.JSON"), md = try file("c.md")
        controller.openFiles([txt, json, md])
        XCTAssertEqual(openURLs, [txt.canonical, json.canonical])
    }

    func testDropOnEditorOpensFile() throws {
        let txt = try file("a.txt")
        let textView = try XCTUnwrap(controller.editor.textView(for: workspace.tabs[0].id) as? FileDropTextView)
        textView.onOpenFiles?([txt])
        XCTAssertEqual(openURLs, [txt.canonical])
    }

    func testDropOnWindowOpensFile() throws {
        let txt = try file("a.txt")
        let content = try XCTUnwrap(controller.window?.contentView as? FileDropView)
        content.onOpenFiles?([txt])
        XCTAssertEqual(openURLs, [txt.canonical])
    }

    func testDockDropBeforeLaunchIsKeptUntilWindowExists() throws {
        let txt = try file("a.txt")
        let delegate = AppDelegate()
        delegate.application(NSApplication.shared, open: [txt])
        XCTAssertEqual(delegate.pendingOpen, [txt])
    }
}
