import AppKit
import SwiftUI
import os

private let logger = Logger(subsystem: "com.meetbell", category: "BannerWindowController")

final class BannerWindowController {
    private var panels: [NSPanel] = []
    private let preferences: PreferencesStore

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    func show(event: CalendarEvent, minutesBefore: Int) {
        logger.info("show: \(event.title), minutesBefore=\(minutesBefore)")
        guard let screen = screenForBanner() else { return }

        let bannerW  = Self.bannerWidth(forScreenWidth: screen.frame.width)
        let bannerH  = BannerLayout.bodyH
        let totalW   = bannerW
        let panelH   = BannerLayout.panelH

        let y = Self.bannerY(
            screenHeight: screen.frame.height,
            verticalPosition: preferences.verticalPosition
        ) + CGFloat(panels.count) * (bannerH + 12)

        let panel = makePanel(width: totalW, height: panelH)

        let hostingView = NSHostingView(rootView:
            BannerView(
                event: event,
                minutesBefore: minutesBefore,
                preferences: preferences,
                onOpen: {
                    Self.openCalendarEvent(event)
                },
                onClose: { [weak panel, weak self] in
                    guard let panel = panel else { return }
                    self?.dismiss(panel: panel)
                },
                onSnooze: { [weak self] in
                    guard let self else { return }
                    let delay = Double(self.preferences.snoozeDuration * 60)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.show(event: event, minutesBefore: minutesBefore)
                    }
                }
            )
        )
        hostingView.layer?.masksToBounds = false
        panel.contentView = hostingView

        let targetX = screen.frame.minX + (screen.frame.width - bannerW) / 2
        let targetY = screen.frame.minY + y - (panelH - bannerH) / 2
        // Start one panelH above target (higher Y = visually above in AppKit's bottom-left origin)
        let offscreenY = targetY + CGFloat(panelH)

        panel.setFrameOrigin(NSPoint(x: targetX, y: offscreenY))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panels.append(panel)

        playAlert()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(NSPoint(x: targetX, y: targetY))
            panel.animator().alphaValue = 1
        }, completionHandler: { [weak self, weak panel] in
            guard let panel = panel else { return }
            let hold = self?.preferences.bannerDuration ?? 300.0
            DispatchQueue.main.asyncAfter(deadline: .now() + hold) { [weak self, weak panel] in
                guard let panel = panel else { return }
                self?.dismissWithAnimation(panel: panel)
            }
        })
    }

    private func dismiss(panel: NSPanel) {
        dismissWithAnimation(panel: panel)
    }

    private func dismissWithAnimation(panel: NSPanel) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak panel] in
            guard let panel = panel else { return }
            self?.remove(panel: panel)
        })
    }

    private func remove(panel: NSPanel) {
        panel.orderOut(nil)
        panels.removeAll { $0 === panel }
    }

    // MARK: - 提醒音效

    private func playAlert() {
        let volume = preferences.alertVolume
        guard volume > 0 else { return }
        if let sound = NSSound(named: NSSound.Name(preferences.alertSound)) {
            sound.volume = Float(volume)
            sound.play()
        }
    }

    // MARK: - 工厂

    private func makePanel(width: CGFloat, height: CGFloat) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func screenForBanner() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    static func bannerWidth(forScreenWidth w: CGFloat) -> CGFloat { min(680, max(440, w * 0.5)) }
    static func bannerY(screenHeight: CGFloat, verticalPosition: Double) -> CGFloat {
        screenHeight * CGFloat(verticalPosition)
    }
    static func verticalOffsets(forCount count: Int, bannerHeight: CGFloat, spacing: CGFloat) -> [CGFloat] {
        (0..<count).map { CGFloat($0) * (bannerHeight + spacing) }
    }

    // MARK: - 打开 Calendar 并显示事件详情

    static func openCalendarEvent(_ event: CalendarEvent) {
        // EKEvent.eventIdentifier 对循环事件会带 ":日期" 后缀，AppleScript 需要 base UID
        let baseUID = event.id.components(separatedBy: ":").first ?? event.id

        // 用 AppleScript 在 Calendar.app 中直接弹出事件详情卡片
        let script = """
        tell application "Calendar"
            activate
            repeat with aCal in calendars
                try
                    set hits to every event of aCal whose uid = "\(baseUID)"
                    if (count of hits) > 0 then
                        show item 1 of hits
                        exit repeat
                    end if
                end try
            end repeat
        end tell
        """

        var errDict: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&errDict)

        // AppleScript 失败时（权限未授予等），直接打开 Calendar.app
        if errDict != nil {
            Self.openCalendarApp()
        }
    }

    private static func openCalendarApp() {
        // 优先通过 bundle ID 定位，避免路径硬编码
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.open(url)
            return
        }
        // 兜底：尝试已知路径
        for path in ["/System/Applications/Calendar.app", "/Applications/Calendar.app"] {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }
}
