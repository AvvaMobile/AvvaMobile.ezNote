import AppKit
import NotepadCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?
    private let fontStore = FontSettingsStore()
    private let lastAppNameKey = "lastAppName"

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateIfRenamed()
        NSApp.mainMenu = MainMenu.build()

        let workspace = Workspace(paths: .live())
        do {
            try workspace.restore()
        } catch {
            showError("Notlar klasörü açılamadı", error)
            NSApp.terminate(nil)
            return
        }
        let controller = MainWindowController(workspace: workspace, font: fontStore.load())
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Çıkışta hiçbir şey sorulmaz: her şey yazılır, sonraki açılışta aynen geri gelir.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        windowController?.flushAll()
        return .terminateNow
    }

    /// Uygulama adı değiştiyse eski adın klasörlerini yeni ada taşır.
    private func migrateIfRenamed() {
        let defaults = UserDefaults.standard
        if let old = defaults.string(forKey: lastAppNameKey), old != AppInfo.name {
            let fm = FileManager.default
            try? FolderMigration.migrate(
                documents: fm.urls(for: .documentDirectory, in: .userDomainMask)[0],
                appSupport: fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0],
                from: old, to: AppInfo.name
            )
        }
        defaults.set(AppInfo.name, forKey: lastAppNameKey)
    }
}

func showError(_ title: String, _ error: Error) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = title
    alert.informativeText = error.localizedDescription
    alert.runModal()
}
