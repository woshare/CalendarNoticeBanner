import SwiftUI
import AppKit

struct HolidayBannerView: View {
    let event: CalendarEvent
    let minutesBefore: Int
    let skin: BannerSkinID
    let preferences: PreferencesStore
    let onOpen: () -> Void
    let onClose: () -> Void
    let onSnooze: () -> Void

    @State private var animTick: Double = 0
    private let ticker = Timer.publish(every: 1.0 / 24.0, on: .main, in: .common).autoconnect()

    private var theme: HolidayTheme { HolidayTheme(skin: skin) }

    private var endTimeString: String? {
        guard preferences.showEndTime else { return nil }
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: event.startDate)
        let endDay   = cal.startOfDay(for: event.endDate)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let endStr = f.string(from: event.endDate)
        if startDay == endDay {
            return "\(f.string(from: event.startDate))–\(endStr)"
        } else {
            return "\(f.string(from: event.startDate))–次日\(endStr)"
        }
    }

    private var timeLabel: String {
        if let et = endTimeString { return et }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: event.startDate)
    }

    var body: some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.backgroundGradient)

            // Top highlight
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)

            // Decorative Canvas layer
            Canvas { ctx, size in
                theme.drawDecorations(ctx, size, animTick)
            }
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Content
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.accentColor.opacity(0.85))
                    .frame(width: 4)
                    .padding(.vertical, 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                        .lineLimit(1)
                    Text(timeLabel)
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundColor(theme.accentColor)
                        .shadow(color: .black.opacity(0.3), radius: 1)
                }

                Spacer()

                HStack(spacing: 6) {
                    Button("稍后") { onSnooze() }
                        .buttonStyle(HolidayButtonStyle(prominent: false, accent: theme.accentColor))
                    Button("打开") { onOpen() }
                        .buttonStyle(HolidayButtonStyle(prominent: true, accent: theme.accentColor))
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: BannerLayout.bodyH)
        .onReceive(ticker) { d in animTick = d.timeIntervalSinceReferenceDate }
    }
}

// MARK: - Theme

struct HolidayTheme {
    let backgroundGradient: LinearGradient
    let accentColor: Color
    let drawDecorations: (GraphicsContext, CGSize, Double) -> Void

    init(skin: BannerSkinID) {
        switch skin {

        case .springFestival:
            backgroundGradient = LinearGradient(
                colors: [Color(red: 0.62, green: 0.04, blue: 0.04), Color(red: 0.85, green: 0.12, blue: 0.08)],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )
            accentColor = Color(red: 0.98, green: 0.84, blue: 0.20)
            drawDecorations = HolidayDecorations.springFestival

        case .lanternFestival:
            backgroundGradient = LinearGradient(
                colors: [Color(red: 0.40, green: 0.03, blue: 0.03), Color(red: 0.65, green: 0.08, blue: 0.05)],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )
            accentColor = Color(red: 1.0, green: 0.80, blue: 0.25)
            drawDecorations = HolidayDecorations.lanternFestival

        case .qingming:
            backgroundGradient = LinearGradient(
                colors: [Color(red: 0.14, green: 0.34, blue: 0.16), Color(red: 0.22, green: 0.48, blue: 0.22)],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )
            accentColor = Color(red: 0.65, green: 0.92, blue: 0.58)
            drawDecorations = HolidayDecorations.qingming

        case .midAutumn:
            backgroundGradient = LinearGradient(
                colors: [Color(red: 0.05, green: 0.06, blue: 0.22), Color(red: 0.10, green: 0.14, blue: 0.38)],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )
            accentColor = Color(red: 0.98, green: 0.88, blue: 0.52)
            drawDecorations = HolidayDecorations.midAutumn

        case .christmas:
            backgroundGradient = LinearGradient(
                colors: [Color(red: 0.38, green: 0.04, blue: 0.06), Color(red: 0.60, green: 0.08, blue: 0.10)],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )
            accentColor = Color(red: 1.0, green: 0.88, blue: 0.50)
            drawDecorations = HolidayDecorations.christmas

        default:
            backgroundGradient = LinearGradient(
                colors: [Color(red: 0.10, green: 0.45, blue: 0.18), Color(red: 0.20, green: 0.65, blue: 0.28)],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )
            accentColor = Color(red: 0.97, green: 0.82, blue: 0.12)
            drawDecorations = { _, _, _ in }
        }
    }
}

// MARK: - Decorations

enum HolidayDecorations {

    // MARK: 春节 — 传统菱形纹 + 金色粒子
    static func springFestival(ctx: GraphicsContext, size: CGSize, t: Double) {
        let gold = Color(red: 0.98, green: 0.84, blue: 0.20)

        // Diamond border pattern top & bottom
        for py in [CGFloat(9), size.height - 9] {
            var x: CGFloat = 18
            while x < size.width - 10 {
                var gc = ctx; gc.opacity = 0.38
                gc.fill(diamondPath(cx: x, cy: py, r: 4.5), with: .color(gold))
                x += 22
            }
        }

        // Vertical divider lines (traditional lattice feel)
        for i in 0..<4 {
            let lx = size.width * CGFloat(i + 1) / 5.0
            var lp = Path()
            lp.move(to: CGPoint(x: lx, y: 6))
            lp.addLine(to: CGPoint(x: lx, y: size.height - 6))
            var gc = ctx; gc.opacity = 0.08
            gc.stroke(lp, with: .color(gold), lineWidth: 0.8)
        }

        // Rising gold sparks
        for i in 0..<18 {
            let seed = Double(i) * 6.13
            let phase = (t * 0.38 + seed * 0.11).truncatingRemainder(dividingBy: 1.0)
            let x = (sin(seed * 1.87) * 0.42 + 0.5) * size.width
            let y = size.height * (1.0 - phase)
            let alpha = min(phase * 5, (1.0 - phase) * 4, 1.0) * 0.70
            let r = CGFloat(1.2 + sin(seed * 2.7) * 1.3)
            var gc = ctx; gc.opacity = alpha
            gc.fill(Path(ellipseIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)), with: .color(gold))
        }
    }

    // MARK: 元宵 — 精细灯笼 + 内光
    static func lanternFestival(ctx: GraphicsContext, size: CGSize, t: Double) {
        let positions: [(CGFloat, Double)] = [(36, 0.0), (size.width / 2, 0.6), (size.width - 36, 1.2)]
        for (lx, phase) in positions {
            let swing = CGFloat(sin(t * 0.9 + phase) * 7)
            drawLantern(ctx: ctx, cx: lx + swing * 0.4, baseTop: 0, size: 26, t: t + phase)
        }
    }

    // MARK: 清明 — 水墨柳枝 + 飘落花瓣
    static func qingming(ctx: GraphicsContext, size: CGSize, t: Double) {
        let green  = Color(red: 0.55, green: 0.85, blue: 0.50)
        let petal  = Color(red: 0.96, green: 0.84, blue: 0.88)

        // Multiple willow strands
        for i in 0..<9 {
            let baseX = size.width * CGFloat(i) / 8.0
            let sway  = CGFloat(sin(t * 0.55 + Double(i) * 1.05) * 7)
            for j in 0..<3 {
                let jf = CGFloat(j) / 2.0 - 0.5
                var p = Path()
                let sx = baseX + jf * 10
                p.move(to: CGPoint(x: sx, y: 0))
                p.addCurve(
                    to:       CGPoint(x: sx + sway + jf * 6, y: size.height * 0.72),
                    control1: CGPoint(x: sx + sway * 0.15,   y: size.height * 0.22),
                    control2: CGPoint(x: sx + sway * 0.55 + jf * 3, y: size.height * 0.48)
                )
                var gc = ctx; gc.opacity = 0.14 + 0.06 * Double(j)
                gc.stroke(p, with: .color(green), lineWidth: 1.2)
            }
        }

        // Drifting cherry blossom petals
        for i in 0..<7 {
            let seed  = Double(i) * 4.11
            let phase = (t * 0.16 + seed * 0.09).truncatingRemainder(dividingBy: 1.0)
            let x     = (sin(seed * 2.05) * 0.36 + 0.5) * size.width + CGFloat(sin(t * 0.45 + seed) * 9)
            let y     = size.height * phase
            let alpha = min(phase * 4, (1.0 - phase) * 3.5, 0.45)
            var gc = ctx; gc.opacity = alpha
            gc.fill(Path(ellipseIn: CGRect(x: x-5, y: y-2.5, width: 10, height: 5)), with: .color(petal))
        }
    }

    // MARK: 中秋 — 月亮 + 星辰
    static func midAutumn(ctx: GraphicsContext, size: CGSize, t: Double) {
        let moonColor = Color(red: 0.98, green: 0.90, blue: 0.58)
        let glowColor = Color(red: 0.95, green: 0.80, blue: 0.30)
        let moonX: CGFloat = size.width - 46
        let moonY: CGFloat = size.height / 2 - 20
        let moonR: CGFloat = 20

        // Moon glow layers
        for layer in 0..<4 {
            let extra = CGFloat(layer) * 9
            let pulse = CGFloat(0.06 + 0.02 * sin(t * 0.6))
            var gc = ctx; gc.opacity = Double(pulse) * Double(4 - layer) / 4.0
            gc.fill(
                Path(ellipseIn: CGRect(x: moonX - extra, y: moonY - extra,
                                       width: (moonR + extra) * 2, height: (moonR + extra) * 2)),
                with: .color(glowColor)
            )
        }

        // Moon body
        ctx.fill(Path(ellipseIn: CGRect(x: moonX, y: moonY, width: moonR*2, height: moonR*2)),
                 with: .color(moonColor))

        // Subtle surface shading
        var shade = ctx; shade.opacity = 0.10
        shade.fill(Path(ellipseIn: CGRect(x: moonX + 8, y: moonY + 5, width: 12, height: 8)),
                   with: .color(Color(red: 0.65, green: 0.55, blue: 0.25)))

        // 8-pointed stars
        let stars: [(CGFloat, CGFloat, CGFloat)] = [
            (0.10, 0.22, 3.5), (0.22, 0.72, 2.8), (0.36, 0.18, 2.2),
            (0.48, 0.68, 3.0), (0.60, 0.28, 2.5), (0.18, 0.48, 2.0), (0.42, 0.45, 1.8)
        ]
        for (i, (fx, fy, r)) in stars.enumerated() {
            let twinkle = 0.38 + 0.32 * sin(t * 1.2 + Double(i) * 1.85)
            var sc = ctx; sc.opacity = twinkle
            sc.fill(starPath(cx: fx * size.width, cy: fy * size.height, r: CGFloat(r)),
                    with: .color(.white))
        }
    }

    // MARK: 圣诞 — 几何雪花 + 落雪
    static func christmas(ctx: GraphicsContext, size: CGSize, t: Double) {
        // Large geometric snowflakes at edges
        let flakes: [(CGFloat, CGFloat, CGFloat)] = [
            (0.06, 0.50, 14), (0.94, 0.50, 12), (0.20, 0.28, 8), (0.80, 0.72, 8)
        ]
        for (fx, fy, r) in flakes {
            drawSnowflake(ctx: ctx, cx: fx * size.width, cy: fy * size.height, r: CGFloat(r), t: t)
        }

        // Falling snow particles
        for i in 0..<14 {
            let seed  = Double(i) * 4.73
            let phase = (t * 0.28 + seed * 0.08).truncatingRemainder(dividingBy: 1.0)
            let x     = (sin(seed * 2.13) * 0.40 + 0.5) * size.width + CGFloat(sin(t * 0.35 + seed) * 7)
            let y     = size.height * phase
            let r     = CGFloat(1.4 + sin(seed * 2.4) * 1.0)
            let alpha = min(phase * 4, (1.0 - phase) * 3.5, 0.60)
            var gc = ctx; gc.opacity = alpha
            gc.fill(Path(ellipseIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)), with: .color(.white))
        }
    }

    // MARK: - Shared helpers

    private static func diamondPath(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: cx,   y: cy-r))
        p.addLine(to: CGPoint(x: cx+r, y: cy))
        p.addLine(to: CGPoint(x: cx,   y: cy+r))
        p.addLine(to: CGPoint(x: cx-r, y: cy))
        p.closeSubpath()
        return p
    }

    private static func starPath(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        var p = Path()
        for i in 0..<8 {
            let angle  = Double(i) * .pi / 4 - .pi / 2
            let radius = i % 2 == 0 ? r : r * 0.42
            let pt     = CGPoint(x: cx + CGFloat(cos(angle)) * radius,
                                 y: cy + CGFloat(sin(angle)) * radius)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }

    private static func drawSnowflake(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, t: Double) {
        let rot = t * 0.12
        var gc  = ctx; gc.opacity = 0.28
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 + rot
            let ex    = cx + CGFloat(cos(angle)) * r
            let ey    = cy + CGFloat(sin(angle)) * r
            var arm   = Path()
            arm.move(to: CGPoint(x: cx, y: cy))
            arm.addLine(to: CGPoint(x: ex, y: ey))
            // Two branches per arm
            for j in 1...2 {
                let bf  = CGFloat(j) / 3.0
                let bx  = cx + CGFloat(cos(angle)) * r * bf
                let by  = cy + CGFloat(sin(angle)) * r * bf
                let br  = r * 0.38
                for sign in [-1.0, 1.0] {
                    let ba = angle + sign * .pi / 4
                    arm.move(to: CGPoint(x: bx, y: by))
                    arm.addLine(to: CGPoint(x: bx + CGFloat(cos(ba)) * br,
                                            y: by + CGFloat(sin(ba)) * br))
                }
            }
            gc.stroke(arm, with: .color(.white), lineWidth: 1.3)
        }
        // Center dot
        var cc = ctx; cc.opacity = 0.35
        cc.fill(Path(ellipseIn: CGRect(x: cx-2, y: cy-2, width: 4, height: 4)), with: .color(.white))
    }

    private static func drawLantern(ctx: GraphicsContext, cx: CGFloat, baseTop: CGFloat, size: CGFloat, t: Double) {
        let gold    = Color(red: 1.0,  green: 0.82, blue: 0.25)
        let red     = Color(red: 0.82, green: 0.08, blue: 0.06)
        let darkRed = Color(red: 0.50, green: 0.04, blue: 0.03)
        let cy      = baseTop + size * 0.9  // lantern center Y

        // Hanging string
        var line = Path()
        line.move(to: CGPoint(x: cx, y: baseTop))
        line.addLine(to: CGPoint(x: cx, y: cy - size * 0.52))
        ctx.stroke(line, with: .color(gold.opacity(0.75)), lineWidth: 1)

        // Top cap
        ctx.fill(
            Path(roundedRect: CGRect(x: cx - size*0.38, y: cy - size*0.52 - 5, width: size*0.76, height: 7),
                 cornerRadius: 2),
            with: .color(gold)
        )

        // Body
        let bodyRect = CGRect(x: cx - size*0.44, y: cy - size*0.52, width: size*0.88, height: size*1.04)
        ctx.fill(Path(ellipseIn: bodyRect), with: .color(red))

        // Vertical ribs
        for j in -1...1 {
            var rib = Path()
            let rx = cx + CGFloat(j) * size * 0.26
            rib.move(to: CGPoint(x: rx, y: cy - size*0.50))
            rib.addLine(to: CGPoint(x: rx, y: cy + size*0.50))
            var rc = ctx; rc.opacity = 0.28
            rc.stroke(rib, with: .color(darkRed), lineWidth: 1.5)
        }

        // Inner warm glow
        let pulse = CGFloat(0.20 + 0.08 * sin(t * 1.5))
        var gc = ctx; gc.opacity = Double(pulse)
        gc.fill(Path(ellipseIn: CGRect(x: cx - size*0.22, y: cy - size*0.28, width: size*0.44, height: size*0.52)),
                with: .color(.orange))

        // Bottom cap
        ctx.fill(
            Path(roundedRect: CGRect(x: cx - size*0.38, y: cy + size*0.50 - 2, width: size*0.76, height: 7),
                 cornerRadius: 2),
            with: .color(gold)
        )

        // Tassels
        for k in -1...1 {
            var tassel = Path()
            let tx = cx + CGFloat(k) * size * 0.18
            tassel.move(to: CGPoint(x: tx, y: cy + size*0.52 + 5))
            tassel.addLine(to: CGPoint(x: tx + CGFloat(k) * 2, y: cy + size*0.52 + 16))
            ctx.stroke(tassel, with: .color(gold.opacity(0.85)), lineWidth: 1.2)
        }
    }
}

// MARK: - Button Style

private struct HolidayButtonStyle: ButtonStyle {
    let prominent: Bool
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(prominent ? .white : .white.opacity(0.80))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(prominent ? accent.opacity(0.45) : Color.white.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(prominent ? accent.opacity(0.70) : Color.white.opacity(0.20), lineWidth: 0.8)
                    )
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
