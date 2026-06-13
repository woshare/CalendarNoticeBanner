import AppKit
import SwiftUI

final class BannerWindowController {
    private var panels: [NSPanel] = []
    private let preferences: PreferencesStore

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    func show(event: CalendarEvent, minutesBefore: Int) {
        print("[MeetBell] show() called: \(event.title), minutesBefore=\(minutesBefore)")
        guard let screen = screenForBanner() else { return }

        let bannerW: CGFloat = Self.bannerWidth(forScreenWidth: screen.frame.width)
        let bannerH: CGFloat = 80
        let charSize: CGFloat = 56
        let charGap: CGFloat  = 6
        let totalW = bannerW + charGap + charSize

        let y = Self.bannerY(
            screenHeight: screen.frame.height,
            verticalPosition: preferences.verticalPosition
        ) + CGFloat(panels.count) * (bannerH + 12)

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
                    Self.openCalendarEvent(event)
                },
                onClose: { [weak panel, weak self] in
                    guard let panel = panel else { return }
                    self?.dismiss(panel: panel)
                }
            )
        )
        hostingView.layer?.masksToBounds = false
        panel.contentView = hostingView

        let startX  = screen.frame.minX - totalW - 20
        let centerX = screen.frame.minX + (screen.frame.width - bannerW) / 2 - charGap - charSize
        let endX    = screen.frame.maxX + 20
        let originY = screen.frame.minY + y - (panelH - bannerH) / 2

        panel.setFrameOrigin(NSPoint(x: startX, y: originY))
        panel.orderFrontRegardless()
        panels.append(panel)

        playAlert()

        // 入场：5秒，平滑S曲线，模拟人跑步拖拽
        animateEntry(panel: panel, from: startX, to: centerX, baseY: originY, duration: 5.0) { [weak self, weak panel] in
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

    // MARK: - 提醒音效

    private func playAlert() {
        let volume = preferences.alertVolume
        guard volume > 0 else { return }
        if let sound = NSSound(named: NSSound.Name(preferences.alertSound)) {
            sound.volume = Float(volume)
            sound.play()
        }
    }

    // MARK: - 入场：平滑 S 曲线 + 跑步步伐振动

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

            // smoothstep S曲线：缓起→匀速拉动→缓停，像人跑步带着横幅
            let smooth = p * p * (3.0 - 2.0 * p)
            let x = startX + (endX - startX) * CGFloat(smooth)

            // 跑步步伐引起的上下振动，频率 ~3步/秒，到站后平息
            let stepFreq = 3.0
            let decayFactor = max(0.0, 1.0 - p * 1.4)
            let bob = CGFloat(4.5 * decayFactor * sin(stepFreq * 2.0 * .pi * p * duration))

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

    // 用 Bool 驱动动画，避免多个 withAnimation 互相覆盖
    @State private var bobbing = false    // 上下弹跳
    @State private var leaning = false   // 前倾角
    @State private var swaying = false   // 左右微晃
    @State private var ropePulled = false // 绳子张紧

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

            // 绳子：连接横幅右端与小人
            Canvas { ctx, size in
                let startX: CGFloat = bannerWidth - 2
                let midY: CGFloat = size.height - bannerHeight / 2
                let endX: CGFloat = bannerWidth + charGap + charSize * 0.12

                var path = Path()
                path.move(to: CGPoint(x: startX, y: midY))
                // 绳子弛度：拉紧时弧度小，松弛时弧度大
                let slack: CGFloat = ropePulled ? 5 : 9
                path.addQuadCurve(
                    to: CGPoint(x: endX, y: midY - 2),
                    control: CGPoint(x: (startX + endX) / 2, y: midY + slack)
                )
                ctx.stroke(path, with: .color(.secondary.opacity(0.55)), lineWidth: 1.5)
            }
            .frame(width: bannerWidth + charGap + charSize, height: panelHeight)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.19).repeatForever(autoreverses: true), value: ropePulled)

            // 小人：静态位置 + 三组独立动画叠加
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.88))
                    .frame(width: charSize, height: charSize)
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)

                Text("🏃")
                    .font(.system(size: charSize * 0.8))
                    .scaleEffect(x: -1, y: 1)  // 水平翻转朝右
            }
            // 动画1：前倾（以脚底为轴，-5°↔-15°）
            .rotationEffect(.degrees(leaning ? -15 : -5), anchor: .bottom)
            .animation(.easeInOut(duration: 0.26).repeatForever(autoreverses: true), value: leaning)
            // 动画2：上下弹跳（12pt，跑步节奏）
            .offset(y: bobbing ? -12 : 0)
            .animation(.easeInOut(duration: 0.19).repeatForever(autoreverses: true), value: bobbing)
            // 静态位置 + 动画3：左右微晃（±2pt）
            .offset(
                x: bannerWidth + charGap + (swaying ? 2 : -2),
                y: -(bannerHeight - charSize) / 2
            )
            .animation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true), value: swaying)
            .frame(width: charSize, height: charSize)
            .onAppear {
                // 各动画独立启动，SwiftUI 会分别跟踪各自 value 的变化
                bobbing    = true
                leaning    = true
                swaying    = true
                ropePulled = true
            }
        }
    }
}
