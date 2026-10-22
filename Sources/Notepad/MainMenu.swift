import AppKit
import NotepadCore

/// Menü aksiyonları responder zincirinde `MainWindowController` ya da `AppDelegate` tarafından karşılanır.
@objc protocol NotepadActions {
    func newTabAction(_ sender: Any?)
    func closeTabAction(_ sender: Any?)
    func openAction(_ sender: Any?)
    func saveAction(_ sender: Any?)
    func saveAsAction(_ sender: Any?)
    func zoomInAction(_ sender: Any?)
    func zoomOutAction(_ sender: Any?)
    func showSettingsAction(_ sender: Any?)
}

enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        let name = AppInfo.name

        main.addSubmenu(name, [
            item("\(name) Hakkında", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item("Ayarlar…", #selector(NotepadActions.showSettingsAction(_:)), ","),
            .separator(),
            item("\(name)'ı Gizle", #selector(NSApplication.hide(_:)), "h"),
            item("Diğerlerini Gizle", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            .separator(),
            item("Çıkış", #selector(NSApplication.terminate(_:)), "q"),
        ])

        main.addSubmenu("Dosya", [
            item("Yeni Sekme", #selector(NotepadActions.newTabAction(_:)), "t"),
            item("Aç…", #selector(NotepadActions.openAction(_:)), "o"),
            .separator(),
            item("Kaydet", #selector(NotepadActions.saveAction(_:)), "s"),
            item("Farklı Kaydet…", #selector(NotepadActions.saveAsAction(_:)), "s", [.command, .shift]),
            .separator(),
            item("Sekmeyi Kapat", #selector(NotepadActions.closeTabAction(_:)), "w"),
        ])

        let find = item("Bul…", #selector(NSTextView.performTextFinderAction(_:)), "f")
        find.tag = NSTextFinder.Action.showFindInterface.rawValue
        let findNext = item("Sonrakini Bul", #selector(NSTextView.performTextFinderAction(_:)), "g")
        findNext.tag = NSTextFinder.Action.nextMatch.rawValue
        main.addSubmenu("Düzen", [
            item("Geri Al", Selector(("undo:")), "z"),
            item("Yinele", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Kes", #selector(NSText.cut(_:)), "x"),
            item("Kopyala", #selector(NSText.copy(_:)), "c"),
            item("Yapıştır", #selector(NSText.paste(_:)), "v"),
            item("Tümünü Seç", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            find,
            findNext,
        ])

        // ⌘= ve Türkçe Q'daki ⌘* da büyütür; onları AppDelegate'teki tuş dinleyicisi yakalar.
        main.addSubmenu("Görünüm", [
            item("Büyüt", #selector(NotepadActions.zoomInAction(_:)), "+"),
            item("Küçült", #selector(NotepadActions.zoomOutAction(_:)), "-"),
        ])

        return main
    }

    private static func item(_ title: String, _ action: Selector, _ key: String = "", _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = mods
        return item
    }
}

private extension NSMenu {
    func addSubmenu(_ title: String, _ items: [NSMenuItem]) {
        let sub = NSMenu(title: title)
        items.forEach(sub.addItem)
        let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        holder.submenu = sub
        addItem(holder)
    }
}
