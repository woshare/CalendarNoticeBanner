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

        // 阶段1：入场滑动（0.5秒 easeOut）
        animateX(panel: panel, from: startX, to: centerX, y: originY, duration: 0.5, easing: easeOut) { [weak self, weak panel] in
            guard let panel = panel else { return }
            let duration = self?.preferences.bannerDuration ?? 5.0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak panel] in
                guard let panel = panel else { return }
                // 阶段3：出场滑动（0.5秒 easeIn）
                self?.animateX(panel: panel, from: centerX, to: endX, y: originY, duration: 0.5, easing: self?.easeIn ?? { $0 }) { [weak self, weak panel] in
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
        animateX(panel: panel, from: currentX, to: endX, y: originY, duration: 0.4, easing: easeIn) { [weak self, weak panel] in
            guard let panel = panel else { return }
            self?.remove(panel: panel)
        }
    }

    private func remove(panel: NSPanel) {
        panel.orderOut(nil)
        panels.removeAll { $0 === panel }
    }

    // MARK: - Timer-based animation（比 NSAnimationContext 对 NSPanel 更可靠）

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
        let fps: Double = 60
        let timer = Timer(timeInterval: 1.0 / fps, repeats: true) { [weak panel] t in
            guard let panel = panel else { t.invalidate(); return }
            let elapsed = Date().timeIntervalSince(startTime)
            let rawProgress = min(elapsed / duration, 1.0)
            let easedProgress = easing(rawProgress)
            let x = startX + (endX - startX) * CGFloat(easedProgress)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            if rawProgress >= 1.0 {
                t.invalidate()
                completion()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func easeOut(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }

    private func easeIn(_ t: Double) -> Double {
        t * t * t
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
