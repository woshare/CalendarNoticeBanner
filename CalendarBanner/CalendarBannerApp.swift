import SwiftUI

@main
struct CalendarBannerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(preferences: AppDelegate.shared.preferences)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!

    let preferences = PreferencesStore()
    private var bannerController: BannerWindowController!
    private var calendarMonitor: CalendarMonitor!
    private var menuBarController: MenuBarController!

    override init() {
        super.init()
        AppDelegate.shared = self
    }

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

        calendarMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        calendarMonitor.stop()
    }
}
