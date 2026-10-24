import Foundation

/// Temp notların (Belgeler altında, görünür) ve uygulama verisinin (Application Support altında) yerleri.
public struct Paths {
    public let notesDir: URL
    public let supportDir: URL

    public var sessionFile: URL { supportDir.appending(path: "session.json") }
    public var pendingDir: URL { supportDir.appending(path: "pending") }

    public init(appName: String = AppInfo.name, documents: URL, appSupport: URL) {
        notesDir = documents.appending(path: appName)
        supportDir = appSupport.appending(path: appName)
    }

    public static func live() -> Paths {
        let fm = FileManager.default
        return Paths(
            documents: fm.urls(for: .documentDirectory, in: .userDomainMask)[0],
            appSupport: fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        )
    }

    public func ensureDirectories() throws {
        for dir in [notesDir, supportDir, pendingDir] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

/// Uygulama adı değişince eski klasörleri yeni ada taşır. Hedef zaten varsa dokunmaz.
/// Notlar klasörü taşınınca oturumdaki yollar da yeni klasöre çevrilir; sekmeler aynı sırayla geri gelsin.
public enum FolderMigration {
    public static func migrate(documents: URL, appSupport: URL, from oldName: String, to newName: String) throws {
        let fm = FileManager.default
        var movedNotes = false
        for base in [documents, appSupport] {
            let old = base.appending(path: oldName)
            let new = base.appending(path: newName)
            guard fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) else { continue }
            try fm.moveItem(at: old, to: new)
            if base == documents { movedNotes = true }
        }
        guard movedNotes else { return }

        let store = SessionStore(file: Paths(appName: newName, documents: documents, appSupport: appSupport).sessionFile)
        guard var session = store.load() else { return }
        let oldPrefix = documents.appending(path: oldName).standardizedFileURL.path + "/"
        let newNotes = documents.appending(path: newName)
        session.tabs = session.tabs.map { record in
            let path = record.kind.url.standardizedFileURL.path
            guard path.hasPrefix(oldPrefix) else { return record }
            let moved = newNotes.appending(path: String(path.dropFirst(oldPrefix.count)))
            return TabRecord(id: record.id, kind: record.kind.isTemp ? .temp(moved) : .file(moved))
        }
        try store.save(session)
    }
}
