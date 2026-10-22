import XCTest
@testable import NotepadCore

/// Her test için geçici, test bitince silinen bir kök klasör.
class TempDirTestCase: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "NotepadTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}

/// Workspace testleri için ortak kurulum: geçici klasörler, her çağrıda 1 sn ilerleyen saat, sahte çöp sepeti.
class WorkspaceTestCase: TempDirTestCase {
    var paths: Paths!
    var trashed: [URL] = []
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        paths = Paths(appName: "Test", documents: root.appending(path: "Docs"), appSupport: root.appending(path: "Sup"))
        trashed = []
    }

    func makeWorkspace() -> Workspace {
        Workspace(
            paths: paths,
            now: { [unowned self] in clock = clock.addingTimeInterval(1); return clock },
            trash: { [unowned self] url in trashed.append(url); try FileManager.default.removeItem(at: url) }
        )
    }

    func restored() throws -> Workspace {
        let ws = makeWorkspace()
        try ws.restore()
        return ws
    }
}
