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

        // 入场：拖拽感动画，完成后等待 bannerDuration 秒再出场
        animateEntry(panel: panel, from: startX, to: centerX, baseY: originY, duration: 2.0) { [weak self, weak panel] in
            guard let panel = panel else { return }
            let holdDuration = self?.preferences.bannerDuration ?? 5.0
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) { [weak self, weak panel] in
                guard let panel = panel else { return }
                self?.animateExit(panel: panel, from: centerX, to: endX, baseY: originY)
            }
        }
    }

    private func dismiss(panel: NSPanel) {
        let screen = NSScreen.screens.first { $0.frame.contains(panel.frame.origin) } ?? NSScreen.main ?? NSScreen.screens[0]
        let endX = screen.frame.maxX + 20
        let currentX = panel.frame.origin.x
        let baseY = panel.frame.origin.y
        animateExit(panel: panel, from: currentX, to: endX, baseY: baseY)
    }

    private func remove(panel: NSPanel) {
        panel.orderOut(nil)
        panels.removeAll { $0 === panel }
    }

    // MARK: - 入场动画：小人拖拽感
    //
    // X 轴：三次方时间扭曲 + spring 过冲
    //   - 前段极慢（小人开始用力拉）
    //   - 中段快速划过屏幕
    //   - 末段轻微过冲 ~8% 后回弹落定
    //
    // Y 轴：走路节奏上下摆动 4pt，接近终点时逐渐消失
    //   模拟小人步伐带动弹窗晃动

    private func animateEntry(
        panel: NSPanel,
        from startX: CGFloat,
        to endX: CGFloat,
        baseY: CGFloat,
        duration: Double,
        completion: @escaping () -> Void
    ) {
        let startTime = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak panel] t in
            guard let panel = panel else { t.invalidate(); return }
            let elapsed = Date().timeIntervalSince(startTime)
            let p = min(elapsed / duration, 1.0)

            // X：三次方扭曲时间轴 → spring
            let u = p * p * p
            let xFraction = CGFloat(1 - exp(-8 * u) * cos(10 * u))
            let x = startX + (endX - startX) * xFraction

            // Y：步伐摆动（3次完整波，幅度随接近终点而消减）
            let bob = CGFloat(4.0 * (1 - p) * sin(6 * Double.pi * p))

            panel.setFrameOrigin(NSPoint(x: x, y: baseY + bob))

            if p >= 1.0 {
                t.invalidate()
                panel.setFrameOrigin(NSPoint(x: endX, y: baseY))
                completion()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - 出场动画：被猛地拽走（t^4 加速，越来越快）

    private func animateExit(
        panel: NSPanel,
        from startX: CGFloat,
        to endX: CGFloat,
        baseY: CGFloat
    ) {
        let startTime = Date()
        let duration = 0.55
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak panel] t in
            guard let panel = panel else { t.invalidate(); return }
            let elapsed = Date().timeIntervalSince(startTime)
            let p = min(elapsed / duration, 1.0)
            let eased = p * p * p * p  // t^4：前段缓，末段猛冲
            let x = startX + (endX - startX) * CGFloat(eased)
            panel.setFrameOrigin(NSPoint(x: x, y: baseY))
            if p >= 1.0 {
                t.invalidate()
                self?.remove(panel: panel)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
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
