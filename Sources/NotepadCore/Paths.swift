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
public enum FolderMigration {
    public static func migrate(documents: URL, appSupport: URL, from oldName: String, to newName: String) throws {
        let fm = FileManager.default
        for base in [documents, appSupport] {
            let old = base.appending(path: oldName)
            let new = base.appending(path: newName)
            guard fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) else { continue }
            try fm.moveItem(at: old, to: new)
        }
    }
}
