import AppKit
import SwiftUI
import NotepadCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?
    private let fontStore = FontSettingsStore()
    private lazy var fontModel = FontModel(settings: fontStore.load())
    private var settingsWindow: NSWindow?
    private let lastAppNameKey = "lastAppName"

    /// Menü kurulmadan önce: macOS View menüsüne "Show Tab Bar" / "Show All Tabs" eklemesin.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateIfRenamed()
        NSApp.mainMenu = MainMenu.build()
        installZoomKeys()

        let workspace = Workspace(paths: .live())
        do {
            try workspace.restore()
        } catch {
            showError("Couldn’t open the notes folder", error)
            NSApp.terminate(nil)
            return
        }
        let controller = MainWindowController(workspace: workspace, font: fontModel.settings)
        fontModel.onChange = { [weak self] settings in
            self?.fontStore.save(settings)
            self?.windowController?.editor.apply(settings)
        }
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Çıkışta hiçbir şey sorulmaz: her şey yazılır, sonraki açılışta aynen geri gelir.
    /// Yalnız bir şey yazılamadıysa uyarılır, çünkü çıkmak o metni kaybettirir.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let error = windowController?.flushAll() else { return .terminateNow }
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Some notes couldn’t be saved"
        alert.informativeText = error.localizedDescription + "\n\nIf you quit, the unsaved changes will be lost."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Quit Anyway").hasDestructiveAction = true
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }

    /// Başka bir uygulamada değişen ve bizde değişmemiş dosyaları yeniden okur.
    func applicationDidBecomeActive(_ notification: Notification) {
        windowController?.workspace.reloadChangedFiles()
    }

    /// ⌘+ Türkçe Q klavyede Shift+4'e denk gelir ve sistemin ekran görüntüsüyle çakışır.
    /// Bu yüzden ⌘= (ABD) ve ⌘* (Türkçe Q'da -'nin solu) da büyütür.
    private func installZoomKeys() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.shift)
            guard mods == .command, let key = event.charactersIgnoringModifiers, ["=", "*"].contains(key) else { return event }
            self?.zoomInAction(nil)
            return nil
        }
    }

    @objc func zoomInAction(_ sender: Any?) {
        fontModel.settings = fontModel.settings.zoomedIn()
    }

    @objc func zoomOutAction(_ sender: Any?) {
        fontModel.settings = fontModel.settings.zoomedOut()
    }

    /// Ana pencere öndeyken ⌘W sekmeyi kapatır (MainWindowController); Ayarlar öndeyse buraya düşer ve onu kapatır.
    @objc func closeTabAction(_ sender: Any?) {
        NSApp.keyWindow?.performClose(nil)
    }

    @objc func showSettingsAction(_ sender: Any?) {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: fontModel)))
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
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
