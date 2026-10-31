import AppKit
import XCTest
@testable import Notepad
@testable import NotepadCore

/// Finder'dan pencereye ya da Dock ikonuna bırakılan metin dosyaları sekmede açılır; diğerleri yok sayılır.
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

    private func file(_ name: String, bytes: [UInt8]) throws -> URL {
        let url = root.appending(path: name)
        try Data(bytes).write(to: url)
        return url
    }

    func testOnlyTextFilesAreTakenFromPasteboard() throws {
        let txt = try file("a.txt"), upper = try file("B.TXT"), json = try file("d.json"), md = try file("c.md")
        let png = try file("e.png", bytes: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00])
        let board = NSPasteboard(name: .init("FileDropTests-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        board.clearContents()
        board.writeObjects([txt, upper, json, md, png] as [NSURL])
        XCTAssertEqual(FileDrop.textFiles(on: board).map(\.canonical), [txt.canonical, upper.canonical, json.canonical, md.canonical])
    }

    func testOpenFilesOpensOnlyTextFiles() throws {
        let txt = try file("a.txt"), json = try file("D.JSON")
        let binary = try file("f.bin", bytes: [0x00, 0x01, 0x02, 0xFF])
        controller.openFiles([txt, json, binary])
        XCTAssertEqual(openURLs, [txt.canonical, json.canonical])
    }

    func testKnownTextTypesAreAccepted() throws {
        for name in ["c.md", "d.html", "e.js", "f.css", "g.xml", "h.csv", "i.swift", "j.py", "k.yaml", "l.sh"] {
            XCTAssertTrue(FileDrop.isText(try file(name)), name)
        }
    }

    func testUnknownTypesWithTextContentAreAccepted() throws {
        for name in ["Makefile", ".env", "a.ts", "b.unknownext", "c.log"] {
            XCTAssertTrue(FileDrop.isText(try file(name)), name)
        }
    }

    func testEmptyFileIsAccepted() throws {
        XCTAssertTrue(FileDrop.isText(try file("empty", bytes: [])))
    }

    func testBinaryContentIsRejected() throws {
        XCTAssertFalse(FileDrop.isText(try file("a.unknownext", bytes: [0x41, 0x00, 0x42])))
        XCTAssertFalse(FileDrop.isText(try file("b.dat", bytes: [0xC3, 0x28, 0xFF, 0xFE])))
        XCTAssertFalse(FileDrop.isText(try file("c.png", bytes: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00])))
    }

    func testMultibyteCharacterSplitAtSniffLimitIsAccepted() throws {
        let bytes = [UInt8](repeating: 0x61, count: FileDrop.sniffLength - 1) + Array("ş".utf8) + Array("son".utf8)
        XCTAssertTrue(FileDrop.isText(try file("long.unknownext", bytes: bytes)))
    }

    func testRtfIsRejected() throws {
        XCTAssertFalse(FileDrop.isText(try file("a.rtf")))
    }

    func testDirectoryIsRejected() throws {
        let dir = root.appending(path: "klasor.txt")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        XCTAssertFalse(FileDrop.isText(dir))
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
