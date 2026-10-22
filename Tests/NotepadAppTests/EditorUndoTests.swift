import AppKit
import XCTest
@testable import Notepad
@testable import NotepadCore

/// Her sekmenin kendi geri al geçmişi olmalı; yoksa ⌘Z gizli sekmedeki metni siler.
final class EditorUndoTests: XCTestCase {
    private var root: URL!
    private var controller: MainWindowController!
    private var workspace: Workspace!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "NotepadAppTests-\(UUID().uuidString)")
        workspace = Workspace(
            paths: Paths(appName: "Test", documents: root.appending(path: "Docs"), appSupport: root.appending(path: "Sup")),
            trash: { try FileManager.default.removeItem(at: $0) }
        )
        try workspace.restore()
        try workspace.newTab()
        controller = MainWindowController(workspace: workspace, font: FontSettings(family: nil, size: 14))
    }

    override func tearDownWithError() throws {
        controller.window?.delegate = nil
        controller.close()
        try? FileManager.default.removeItem(at: root)
    }

    private func textView(_ index: Int) -> NSTextView {
        controller.editor.textView(for: workspace.tabs[index].id)!
    }

    func testEachTabTextViewHasItsOwnUndoManager() {
        let a = textView(0).undoManager
        let b = textView(1).undoManager
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertFalse(a === b)
    }

    func testUndoInOneTabDoesNotTouchAnother() {
        textView(0).insertText("A notu", replacementRange: NSRange(location: 0, length: 0))
        textView(1).insertText("B", replacementRange: NSRange(location: 0, length: 0))
        let undo = textView(1).undoManager!
        while undo.canUndo { undo.undo() }
        XCTAssertEqual(textView(0).string, "A notu")
        XCTAssertEqual(workspace.tabs[0].text, "A notu")
    }

    func testExternalReloadClearsUndoHistory() throws {
        textView(0).insertText("eski", replacementRange: NSRange(location: 0, length: 0))
        XCTAssertTrue(textView(0).undoManager!.canUndo)
        let doc = workspace.tabs[0]
        try workspace.flush(doc.id)
        try TextFile.write("dışarıdan", to: doc.kind.url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: doc.kind.url.path)
        workspace.reloadChangedFiles()
        XCTAssertEqual(textView(0).string, "dışarıdan")
        XCTAssertFalse(textView(0).undoManager!.canUndo)
    }

    func testClosingTabDropsItsUndoManager() throws {
        let closed = workspace.tabs[1].id
        _ = textView(1).undoManager
        try workspace.close(closed, discard: true)
        XCTAssertNil(controller.editor.undoManagers[closed])
    }
}
