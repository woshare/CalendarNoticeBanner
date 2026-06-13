import SwiftUI

@main
struct CalendarBannerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(preferences: appDelegate.preferences)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = PreferencesStore()
    private var bannerController: BannerWindowController!
    private var calendarMonitor: CalendarMonitor!
    private var menuBarController: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        bannerController = BannerWindowController(preferences: preferences)
        calendarMonitor = CalendarMonitor(preferences: preferences)
        menuBarController = MenuBarController(
            preferences: preferences,
            bannerController: bannerController
        )

        calendarMonitor.onTrigger = { [weak self] event, minutesBefore in
            self?.bannerController.show(event: event, minutesBefore: minutesBefore)
        }

        calendarMonitor.onPermissionDenied = { [weak self] in
            self?.menuBarController.showPermissionWarning()
        }

        menuBarController.onForceCheck = { [weak self] in
            self?.calendarMonitor.forceCheckNow()
        }

        calendarMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        calendarMonitor.stop()
    }
}
