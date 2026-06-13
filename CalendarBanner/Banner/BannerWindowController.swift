import AppKit
import SwiftUI

final class BannerWindowController {
    private var panels: [NSPanel] = []
    private let preferences: PreferencesStore

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    func show(event: CalendarEvent, minutesBefore: Int) {
        print("[CalendarBanner] show() called: \(event.title), minutesBefore=\(minutesBefore)")
        guard let screen = screenForBanner() else { return }

        let bannerW: CGFloat = Self.bannerWidth(forScreenWidth: screen.frame.width)
        let bannerH: CGFloat = 80
        let charSize: CGFloat = 56          // 小人尺寸
        let charGap: CGFloat  = 6           // 小人与横幅的间距
        // 整体面板宽度 = 横幅 + 间距 + 小人（小人从横幅右侧探出）
        let totalW = bannerW + charGap + charSize

        let y = Self.bannerY(
            screenHeight: screen.frame.height,
            verticalPosition: preferences.verticalPosition
        ) + CGFloat(panels.count) * (bannerH + 12)

        // 用一个稍高的面板容纳小人（小人可以上下摆动超出横幅区域）
        let panelH = bannerH + charSize * 0.4
        let panel = makePanel(width: totalW, height: panelH)

        let hostingView = NSHostingView(rootView:
            BannerWithCharacter(
                event: event,
                minutesBefore: minutesBefore,
                preferences: preferences,
                bannerWidth: bannerW,
                bannerHeight: bannerH,
                charSize: charSize,
                charGap: charGap,
                panelHeight: panelH,
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
            )
        )
        // 允许 SwiftUI 内容溢出 panel 边界（小人摆动时）
        hostingView.layer?.masksToBounds = false
        panel.contentView = hostingView

        let startX  = screen.frame.minX - totalW - 20
        let centerX = screen.frame.minX + (screen.frame.width - bannerW) / 2 - charGap - charSize
        let endX    = screen.frame.maxX + 20
        // Y 让横幅居中于面板
        let originY = screen.frame.minY + y - (panelH - bannerH) / 2

        panel.setFrameOrigin(NSPoint(x: startX, y: originY))
        panel.orderFrontRegardless()
        panels.append(panel)

        animateEntry(panel: panel, from: startX, to: centerX, baseY: originY, duration: 2.2) { [weak self, weak panel] in
            guard let panel = panel else { return }
            let hold = self?.preferences.bannerDuration ?? 5.0
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

    private func remove(panel: NSPanel) {
        panel.orderOut(nil)
        panels.removeAll { $0 === panel }
    }

    // MARK: - 入场：慢起→加速→轻微过冲→落定（cubic warp + spring）

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
            let p = min(Date().timeIntervalSince(startTime) / duration, 1.0)

            // 三次方扭曲 → spring：前段极慢，中段冲刺，末段过冲~8%后落定
            let u = p * p * p
            let x = startX + (endX - startX) * CGFloat(1 - exp(-8 * u) * cos(10 * u))
            // 整体面板上下微幅晃动（2pt），模拟被拽动时的惯性
            let bob = CGFloat(2.0 * (1 - p) * sin(6 * Double.pi * p))
            panel.setFrameOrigin(NSPoint(x: x, y: baseY + bob))

            if p >= 1.0 {
                t.invalidate()
                panel.setFrameOrigin(NSPoint(x: endX, y: baseY))
                completion()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - 出场：t^4 越来越快，像被猛地拽走

    private func animateExit(panel: NSPanel, from startX: CGFloat, to endX: CGFloat, baseY: CGFloat) {
        let startTime = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak panel] t in
            guard let panel = panel else { t.invalidate(); return }
            let p = min(Date().timeIntervalSince(startTime) / 0.55, 1.0)
            panel.setFrameOrigin(NSPoint(x: startX + (endX - startX) * CGFloat(p * p * p * p), y: baseY))
            if p >= 1.0 { t.invalidate(); self?.remove(panel: panel) }
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
}

// MARK: - 横幅 + 小人 合体视图

struct BannerWithCharacter: View {
    let event: CalendarEvent
    let minutesBefore: Int
    let preferences: PreferencesStore
    let bannerWidth: CGFloat
    let bannerHeight: CGFloat
    let charSize: CGFloat
    let charGap: CGFloat
    let panelHeight: CGFloat
    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?

    // 跑步动画三个维度
    @State private var bobY: CGFloat = 0       // 上下弹跳（步伐）
    @State private var lean: Double = -6       // 前倾角（拽东西时身体前倾）
    @State private var sway: CGFloat = 0       // 左右微晃（重心转移）

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(width: bannerWidth + charGap + charSize, height: panelHeight)

            // 横幅本体
            BannerView(
                event: event,
                minutesBefore: minutesBefore,
                preferences: preferences,
                onOpen: onOpen,
                onClose: onClose
            )
            .frame(width: bannerWidth, height: bannerHeight)
            .alignmentGuide(.bottom) { d in d[.bottom] }

            // 小人：三轴动画叠加 → 真实跑步感
            Text("🏃")
                .font(.system(size: charSize * 0.8))
                // 水平翻转朝右（拉着横幅跑）
                .scaleEffect(x: -1, y: 1)
                // 身体前倾（以脚底为轴旋转，-6° ~ -14° 始终保持前倾）
                .rotationEffect(.degrees(lean), anchor: .bottom)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.88))
                        .frame(width: charSize, height: charSize)
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                )
                .frame(width: charSize, height: charSize)
                .offset(
                    x: bannerWidth + charGap + sway,
                    y: -(bannerHeight - charSize) / 2 + bobY
                )
                .onAppear {
                    // 1. 上下弹跳：0.22s，跑步节奏（快）
                    withAnimation(.easeInOut(duration: 0.22).repeatForever(autoreverses: true)) {
                        bobY = -9
                    }
                    // 2. 前倾交替：0.26s，-6°↔-14°，始终朝前倾（拽东西的发力感）
                    withAnimation(.easeInOut(duration: 0.26).repeatForever(autoreverses: true)) {
                        lean = -14
                    }
                    // 3. 左右微晃：0.32s，重心在两脚间转移
                    withAnimation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true)) {
                        sway = 3
                    }
                }
        }
    }
}
