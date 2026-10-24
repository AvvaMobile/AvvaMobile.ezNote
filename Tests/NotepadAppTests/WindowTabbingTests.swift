import AppKit
import XCTest
@testable import Notepad
@testable import NotepadCore

/// Kendi sekme çubuğumuz var; macOS'un pencere sekmeleri ("Show Tab Bar") ikinci bir çubuk açmasın.
final class WindowTabbingTests: XCTestCase {
    func testMainWindowDisallowsSystemTabs() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "NotepadAppTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = Workspace(paths: Paths(appName: "Test", documents: root.appending(path: "Docs"), appSupport: root.appending(path: "Sup")))
        try workspace.restore()
        let controller = MainWindowController(workspace: workspace, font: FontSettings(family: nil, size: 14))
        defer { controller.window?.delegate = nil; controller.close() }
        XCTAssertEqual(controller.window?.tabbingMode, .disallowed)
    }
}
