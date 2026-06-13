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

        animateEntry(
            panel: panel,
            bannerWidth: width,
            bannerHeight: height,
            from: startX,
            to: centerX,
            baseY: originY,
            duration: 2.0
        ) { [weak self, weak panel] in
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
        animateExit(panel: panel, from: panel.frame.origin.x, to: endX, baseY: panel.frame.origin.y)
    }

    private func remove(panel: NSPanel) {
        panel.orderOut(nil)
        panels.removeAll { $0 === panel }
    }

    // MARK: - 入场：小人拉着横幅从左侧走入
    //
    // 小人面朝右跑动，紧贴横幅右边缘（前方引导），步伐幅度比横幅大。
    // 横幅抵达终点前小人渐隐离开。
    // X：三次方时间扭曲 + spring 过冲，模拟"费力拽起重物"手感。

    private func animateEntry(
        panel: NSPanel,
        bannerWidth: CGFloat,
        bannerHeight: CGFloat,
        from startX: CGFloat,
        to endX: CGFloat,
        baseY: CGFloat,
        duration: Double,
        completion: @escaping () -> Void
    ) {
        let charSize: CGFloat = 44
        let charPanel = makeCharacterPanel(size: charSize)
        charPanel.orderFrontRegardless()

        let startTime = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak panel] t in
            guard let panel = panel else {
                t.invalidate()
                charPanel.orderOut(nil)
                return
            }
            let elapsed = Date().timeIntervalSince(startTime)
            let p = min(elapsed / duration, 1.0)

            // X：三次方扭曲 → spring（前段极慢，中段冲刺，末段过冲回弹）
            let u = p * p * p
            let xFraction = CGFloat(1 - exp(-8 * u) * cos(10 * u))
            let bannerX = startX + (endX - startX) * xFraction

            // 横幅：微幅垂直晃动（2.5pt，模拟被拽动时的晃荡）
            let bannerBob = CGFloat(2.5 * (1 - p) * sin(6 * Double.pi * p))
            panel.setFrameOrigin(NSPoint(x: bannerX, y: baseY + bannerBob))

            // 小人：紧贴横幅右边 4pt，步伐幅度更大（7pt），相位偏移 0.6 rad
            let charX = bannerX + bannerWidth + 4
            let charBob = CGFloat(7.0 * (1 - p) * sin(6 * Double.pi * p + 0.6))
            let charY = baseY + bannerBob + charBob + (bannerHeight - charSize) / 2.0
            charPanel.setFrameOrigin(NSPoint(x: charX, y: charY))

            // 最后 25% 小人渐隐（横幅已接近终点，小人"放手"离开）
            let charAlpha = p < 0.75 ? 1.0 : (1.0 - p) / 0.25
            charPanel.alphaValue = CGFloat(max(0, charAlpha))

            if p >= 1.0 {
                t.invalidate()
                panel.setFrameOrigin(NSPoint(x: endX, y: baseY))
                charPanel.orderOut(nil)
                completion()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // 小人使用 figure.run SF Symbol，独立透明小窗口
    private func makeCharacterPanel(size: CGFloat) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: -400, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = NSHostingView(rootView:
            Image(systemName: "figure.run")
                .font(.system(size: size * 0.78, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
        )
        panel.contentView = view
        return panel
    }

    // MARK: - 出场：被猛地拽走（t^4 加速）

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
            let x = startX + (endX - startX) * CGFloat(p * p * p * p)
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
