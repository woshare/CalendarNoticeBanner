import AppKit
import SwiftUI

final class MenuBarController {
    private var statusItem: NSStatusItem!
    private let preferences: PreferencesStore
    private let bannerController: BannerWindowController
    private var settingsWindow: NSWindow?
    var onForceCheck: (() -> Void)?

    init(preferences: PreferencesStore, bannerController: BannerWindowController) {
        self.preferences = preferences
        self.bannerController = bannerController
        setup()
    }

    private func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "calendar.badge.clock",
                                           accessibilityDescription: "MeetBell")
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let infoItem = NSMenuItem(title: "今日事件：加载中...", action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        infoItem.tag = 100
        menu.addItem(infoItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "偏好设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let forceCheckItem = NSMenuItem(title: "立即检查日历", action: #selector(forceCheckNow), keyEquivalent: "r")
        forceCheckItem.target = self
        menu.addItem(forceCheckItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "退出 MeetBell",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    func updateEventCount(_ count: Int) {
        if let item = statusItem.menu?.item(withTag: 100) {
            item.title = "今日事件：\(count) 个"
        }
    }

    func showPermissionWarning() {
        statusItem.button?.image = NSImage(systemSymbolName: "calendar.badge.exclamationmark",
                                           accessibilityDescription: "需要日历权限")
        if let item = statusItem.menu?.item(withTag: 100) {
            item.title = "⚠️ 需要日历权限"
        }
        if statusItem.menu?.item(withTag: 101) == nil {
            let settingsItem = NSMenuItem(
                title: "前往系统设置授权...",
                action: #selector(openCalendarSettings),
                keyEquivalent: ""
            )
            settingsItem.target = self
            settingsItem.tag = 101
            statusItem.menu?.insertItem(settingsItem, at: 1)
        }
    }

    @objc private func openCalendarSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        )
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(preferences: preferences)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "MeetBell 偏好设置"
            window.styleMask = [.titled, .closable]
            window.center()
            settingsWindow = window
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.settingsWindow = nil
            }
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func forceCheckNow() {
        onForceCheck?()
    }


}
