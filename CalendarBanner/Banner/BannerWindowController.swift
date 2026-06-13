import AppKit
import SwiftUI

final class BannerWindowController {
    private var panels: [NSPanel] = []
    private let preferences: PreferencesStore

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    func show(event: CalendarEvent, minutesBefore: Int) {
        guard let screen = screenForBanner() else { return }

        let width = Self.bannerWidth(forScreenWidth: screen.frame.width)
        let height: CGFloat = 80
        let y = Self.bannerY(
            screenHeight: screen.frame.height,
            verticalPosition: preferences.verticalPosition
        ) + CGFloat(panels.count) * (height + 12)

        let panel = makePanel(width: width, height: height)
        let hostingView = NSHostingView(rootView: BannerView(
            event: event,
            minutesBefore: minutesBefore,
            preferences: preferences,
            onOpen: {
                let interval = event.startDate.timeIntervalSinceReferenceDate
                if let url = URL(string: "calshow:\(Int(interval))") {
                    NSWorkspace.shared.open(url)
                }
            },
            onClose: { [weak panel, weak self] in
                guard let panel = panel else { return }
                self?.dismiss(panel: panel)
            }
        ))
        panel.contentView = hostingView

        let startX = screen.frame.minX - width - 20
        let centerX = screen.frame.minX + (screen.frame.width - width) / 2
        let endX = screen.frame.maxX + 20
        let originY = screen.frame.minY + y

        panel.setFrameOrigin(NSPoint(x: startX, y: originY))
        panel.orderFrontRegardless()
        panels.append(panel)

        // 入场：1.0s spring 弹性缓动（慢起→加速→轻微过冲→回弹落定）
        animateX(panel: panel, from: startX, to: centerX, y: originY, duration: 1.0, easing: springEaseOut) { [weak self, weak panel] in
            guard let panel = panel else { return }
            let duration = self?.preferences.bannerDuration ?? 5.0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak panel] in
                guard let panel = panel else { return }
                // 出场：0.6s 强 easeIn（越来越快，像被拉走）
                self?.animateX(panel: panel, from: centerX, to: endX, y: originY, duration: 0.6, easing: self?.strongEaseIn ?? { $0 }) { [weak self, weak panel] in
                    guard let panel = panel else { return }
                    self?.remove(panel: panel)
                }
            }
        }
    }

    private func dismiss(panel: NSPanel) {
        let screen = NSScreen.screens.first { $0.frame.contains(panel.frame.origin) } ?? NSScreen.main ?? NSScreen.screens[0]
        let endX = screen.frame.maxX + 20
        let currentX = panel.frame.origin.x
        let originY = panel.frame.origin.y
        animateX(panel: panel, from: currentX, to: endX, y: originY, duration: 0.4, easing: strongEaseIn) { [weak self, weak panel] in
            guard let panel = panel else { return }
            self?.remove(panel: panel)
        }
    }

    private func remove(panel: NSPanel) {
        panel.orderOut(nil)
        panels.removeAll { $0 === panel }
    }

    // MARK: - Timer-based animation

    private func animateX(
        panel: NSPanel,
        from startX: CGFloat,
        to endX: CGFloat,
        y: CGFloat,
        duration: Double,
        easing: @escaping (Double) -> Double,
        completion: @escaping () -> Void
    ) {
        let startTime = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak panel] t in
            guard let panel = panel else { t.invalidate(); return }
            let elapsed = Date().timeIntervalSince(startTime)
            let rawProgress = min(elapsed / duration, 1.0)
            let x = startX + (endX - startX) * CGFloat(easing(rawProgress))
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            if rawProgress >= 1.0 {
                t.invalidate()
                completion()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // 弹性缓动：慢起 → 加速 → 轻微过冲约 8% → 回弹落定
    // 模拟小人拽着重物从左走到右，到位后惯性摆动一下
    private func springEaseOut(_ t: Double) -> Double {
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        return 1 - exp(-8 * t) * cos(10 * t)
    }

    // 强 easeIn：越来越快，模拟被猛地拽走
    private func strongEaseIn(_ t: Double) -> Double {
        t * t * t * t
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
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func screenForBanner() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    // MARK: - 静态工具

    static func bannerWidth(forScreenWidth screenWidth: CGFloat) -> CGFloat {
        min(680, max(440, screenWidth * 0.5))
    }

    static func bannerY(screenHeight: CGFloat, verticalPosition: Double) -> CGFloat {
        screenHeight * CGFloat(verticalPosition)
    }

    static func verticalOffsets(forCount count: Int, bannerHeight: CGFloat, spacing: CGFloat) -> [CGFloat] {
        (0..<count).map { CGFloat($0) * (bannerHeight + spacing) }
    }
}
