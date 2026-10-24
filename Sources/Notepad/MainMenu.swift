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
            item("About \(name)", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item("Settings…", #selector(NotepadActions.showSettingsAction(_:)), ","),
            .separator(),
            item("Hide \(name)", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            .separator(),
            item("Quit \(name)", #selector(NSApplication.terminate(_:)), "q"),
        ])

        main.addSubmenu("File", [
            item("New Tab", #selector(NotepadActions.newTabAction(_:)), "t"),
            item("Open…", #selector(NotepadActions.openAction(_:)), "o"),
            .separator(),
            item("Save", #selector(NotepadActions.saveAction(_:)), "s"),
            item("Save As…", #selector(NotepadActions.saveAsAction(_:)), "s", [.command, .shift]),
            .separator(),
            item("Close Tab", #selector(NotepadActions.closeTabAction(_:)), "w"),
        ])

        let find = item("Find…", #selector(NSTextView.performTextFinderAction(_:)), "f")
        find.tag = NSTextFinder.Action.showFindInterface.rawValue
        let findNext = item("Find Next", #selector(NSTextView.performTextFinderAction(_:)), "g")
        findNext.tag = NSTextFinder.Action.nextMatch.rawValue
        main.addSubmenu("Edit", [
            item("Undo", Selector(("undo:")), "z"),
            item("Redo", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            find,
            findNext,
        ])

        // ⌘= ve Türkçe Q'daki ⌘* da büyütür; onları AppDelegate'teki tuş dinleyicisi yakalar.
        main.addSubmenu("View", [
            item("Zoom In", #selector(NotepadActions.zoomInAction(_:)), "+"),
            item("Zoom Out", #selector(NotepadActions.zoomOutAction(_:)), "-"),
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
