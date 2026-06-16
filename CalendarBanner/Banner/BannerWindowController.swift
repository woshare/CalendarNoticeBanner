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
        let panelH   = BannerLayout.panelHeight(for: preferences.bannerSkin.resolved())

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

        let startX  = screen.frame.minX - totalW - 20
        let centerX = screen.frame.minX + (screen.frame.width - bannerW) / 2
        let endX    = screen.frame.maxX + 20
        let originY = screen.frame.minY + y - (panelH - bannerH) / 2

        panel.setFrameOrigin(NSPoint(x: startX, y: originY))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panels.append(panel)

        playAlert()

        // 入场：S 曲线滑入 + 步伐振动，开头 0.5s 淡入
        animateEntry(panel: panel, from: startX, to: centerX, baseY: originY, duration: 5.0) { [weak self, weak panel] in
            guard let panel = panel else { return }
            let hold = self?.preferences.bannerDuration ?? 300.0
            DispatchQueue.main.asyncAfter(deadline: .now() + hold) { [weak self, weak panel] in
                guard let panel = panel else { return }
                self?.animateExit(panel: panel, from: centerX, to: endX, baseY: originY)
            }
        }
    }

    private func dismiss(panel: NSPanel) {
        let screen = NSScreen.screens.first { $0.frame.contains(panel.frame.origin) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let endX = screen.frame.maxX + 20
        animateExit(panel: panel, from: panel.frame.origin.x, to: endX, baseY: panel.frame.origin.y)
    }

    // MARK: - 入场：平滑 S 曲线 + 步伐振动 + 淡入

    private func animateEntry(
        panel: NSPanel,
        from startX: CGFloat,
        to endX: CGFloat,
        baseY: CGFloat,
        duration: Double,
        completion: @escaping () -> Void
    ) {
        let startTime = Date()
        let fadeInDuration = 0.5  // 前 0.5s 淡入
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak panel] t in
            guard let panel = panel else { t.invalidate(); return }
            let elapsed = Date().timeIntervalSince(startTime)
            let p = min(elapsed / duration, 1.0)

            // 平滑 S 曲线：缓起→匀速→缓停
            let smooth = p * p * (3.0 - 2.0 * p)
            let x = startX + (endX - startX) * CGFloat(smooth)

            // 步伐振动：到站后平息
            let stepFreq = 3.0
            let decayFactor = max(0.0, 1.0 - p * 1.4)
            let bob = CGFloat(4.5 * decayFactor * sin(stepFreq * 2.0 * .pi * p * duration))

            // 淡入：前 fadeInDuration 秒从 0 → 1
            panel.alphaValue = CGFloat(min(elapsed / fadeInDuration, 1.0))

            panel.setFrameOrigin(NSPoint(x: x, y: baseY + bob))

            if p >= 1.0 {
                t.invalidate()
                panel.alphaValue = 1
                panel.setFrameOrigin(NSPoint(x: endX, y: baseY))
                completion()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - 出场：t⁴ 加速 + 末尾淡出

    private func animateExit(panel: NSPanel, from startX: CGFloat, to endX: CGFloat, baseY: CGFloat) {
        let startTime = Date()
        let exitDuration = 0.55
        let fadeOutStart = 0.75  // 后 25% 开始淡出（约 0.14s）
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak panel] t in
            guard let panel = panel else { t.invalidate(); return }
            let p = min(Date().timeIntervalSince(startTime) / exitDuration, 1.0)
            panel.setFrameOrigin(NSPoint(x: startX + (endX - startX) * CGFloat(p * p * p * p), y: baseY))
            // 末尾淡出
            if p >= fadeOutStart {
                panel.alphaValue = CGFloat(1.0 - (p - fadeOutStart) / (1.0 - fadeOutStart))
            }
            if p >= 1.0 { t.invalidate(); self?.remove(panel: panel) }
        }
        RunLoop.main.add(timer, forMode: .common)
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
