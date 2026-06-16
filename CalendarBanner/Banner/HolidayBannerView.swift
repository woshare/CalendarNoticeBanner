import SwiftUI
import AppKit

// Content zone within the 220pt panel
private let kPanelH: CGFloat = BannerLayout.holidayPanelH  // 220
private let kBodyH:  CGFloat = BannerLayout.bodyH           // 80
private let kTopY:   CGFloat = (kPanelH - kBodyH) / 2      // 70
private let kBotY:   CGFloat = kTopY + kBodyH               // 150
private let kMidY:   CGFloat = kTopY + kBodyH / 2           // 110

struct HolidayBannerView: View {
    let event: CalendarEvent
    let minutesBefore: Int
    let skin: BannerSkinID
    let preferences: PreferencesStore
    let onOpen: () -> Void
    let onClose: () -> Void
    let onSnooze: () -> Void

    private var endTimeString: String? {
        guard preferences.showEndTime else { return nil }
        let cal = Calendar.current
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        let startDay = cal.startOfDay(for: event.startDate)
        let endDay   = cal.startOfDay(for: event.endDate)
        if startDay == endDay {
            return "\(f.string(from: event.startDate))–\(f.string(from: event.endDate))"
        } else {
            return "\(f.string(from: event.startDate))–次日\(f.string(from: event.endDate))"
        }
    }

    private var timeLabel: String {
        if let et = endTimeString { return et }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: event.startDate)
    }

    private var accent: Color {
        switch skin {
        case .springFestival:  return Color(red: 0.98, green: 0.84, blue: 0.20)
        case .lanternFestival: return Color(red: 1.00, green: 0.80, blue: 0.25)
        case .qingming:        return Color(red: 0.72, green: 0.96, blue: 0.62)
        case .midAutumn:       return Color(red: 0.98, green: 0.88, blue: 0.52)
        case .christmas:       return Color(red: 1.00, green: 0.88, blue: 0.50)
        default:               return .white
        }
    }

    // Extra trailing inset for skins where right side has a notch/point
    private var trailingInset: CGFloat {
        skin == .christmas ? 42 : 0
    }

    // Extra leading inset for skins where left side has a point
    private var leadingInset: CGFloat {
        skin == .springFestival ? 6 : 0
    }

    var body: some View {
        ZStack(alignment: .center) {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    SkinCanvas.draw(skin: skin, ctx: ctx, size: size, t: t)
                }
            }
            .allowsHitTesting(false)

            // Content row — centered in the 220pt frame
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(accent.opacity(0.85))
                    .frame(width: 4)
                    .padding(.vertical, 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.40), radius: 2, x: 0, y: 1)
                        .lineLimit(1)
                    Text(timeLabel)
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundColor(accent)
                        .shadow(color: .black.opacity(0.30), radius: 1)
                }

                Spacer()

                HStack(spacing: 6) {
                    Button("稍后") { onSnooze() }
                        .buttonStyle(HolidayButtonStyle(prominent: false, accent: accent))
                    Button("打开") { onOpen() }
                        .buttonStyle(HolidayButtonStyle(prominent: true, accent: accent))
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 22, height: 22)
                }
            }
            .padding(.leading, 14 + leadingInset)
            .padding(.trailing, 14 + trailingInset)
            .frame(height: kBodyH)
        }
        .frame(height: kPanelH)
    }
}

// MARK: - Per-Skin Canvas Renderer

enum SkinCanvas {

    static func draw(skin: BannerSkinID, ctx: GraphicsContext, size: CGSize, t: Double) {
        switch skin {
        case .springFestival:  springFestival(ctx: ctx, size: size, t: t)
        case .lanternFestival: lanternFestival(ctx: ctx, size: size, t: t)
        case .qingming:        qingming(ctx: ctx, size: size, t: t)
        case .midAutumn:       midAutumn(ctx: ctx, size: size, t: t)
        case .christmas:       christmas(ctx: ctx, size: size, t: t)
        default: break
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 春节 — 两端尖头菱形横幅 ◁━━━━━▷ + 金色粒子
    // ─────────────────────────────────────────────────────────────────────────

    static func springFestival(ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width
        let pW: CGFloat = 32   // point depth from edge to rect body
        let cR: CGFloat = 8    // corner radius at rectangular portion

        let shape = hexBanner(w: w, topY: kTopY, botY: kBotY, midY: kMidY, pW: pW, cR: cR)

        // Deep crimson gradient
        ctx.fill(shape, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.48, green: 0.02, blue: 0.02), location: 0.0),
                .init(color: Color(red: 0.78, green: 0.09, blue: 0.06), location: 0.45),
                .init(color: Color(red: 0.55, green: 0.04, blue: 0.03), location: 1.0),
            ]),
            startPoint: CGPoint(x: 0, y: kTopY),
            endPoint:   CGPoint(x: w, y: kBotY)
        ))

        // Gold outer border
        ctx.stroke(shape, with: .color(Color(red: 0.96, green: 0.78, blue: 0.14)), lineWidth: 2.2)

        // Inner content clipped to shape
        var cl = ctx; cl.clip(to: shape)

        // Diamond border trim along top & bottom
        let gold = Color(red: 0.98, green: 0.84, blue: 0.20)
        var x: CGFloat = pW + 20
        while x < w - pW - 12 {
            var d = cl; d.opacity = 0.45
            d.fill(diamond(cx: x, cy: kTopY + 9,  r: 4.5), with: .color(gold))
            d.fill(diamond(cx: x, cy: kBotY - 9, r: 4.5), with: .color(gold))
            x += 24
        }

        // 福 character watermark in center
        var wm = cl; wm.opacity = 0.06
        let fuText = cl.resolve(Text("福").font(.system(size: 56, weight: .bold)))
        cl.draw(fuText, at: CGPoint(x: w / 2, y: kMidY), anchor: .center)

        // Rising gold sparks
        for i in 0..<20 {
            let seed  = Double(i) * 5.89
            let phase = (t * 0.38 + seed * 0.11).truncatingRemainder(dividingBy: 1.0)
            let px    = (sin(seed * 1.77) * 0.40 + 0.5) * w
            let py    = kBotY - kBodyH * CGFloat(phase)
            let alpha = min(phase * 4, (1.0 - phase) * 3, 0.75)
            let r     = CGFloat(1.0 + sin(seed * 2.5) * 1.3)
            var gc    = cl; gc.opacity = alpha
            gc.fill(Path(ellipseIn: CGRect(x: px-r, y: py-r, width: r*2, height: r*2)), with: .color(gold))
        }

        // Gold point caps at tips
        ctx.fill(diamond(cx: 0, cy: kMidY, r: 7), with: .color(gold))
        ctx.fill(diamond(cx: w, cy: kMidY, r: 7), with: .color(gold))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 元宵 — 内容栏 + 下方悬挂三盏灯笼
    // ─────────────────────────────────────────────────────────────────────────

    static func lanternFestival(ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width

        // Main content bar
        let barPath = Path(roundedRect: CGRect(x: 0, y: kTopY, width: w, height: kBodyH), cornerRadius: 14)
        ctx.fill(barPath, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.22, green: 0.02, blue: 0.02),
                Color(red: 0.52, green: 0.06, blue: 0.04),
            ]),
            startPoint: CGPoint(x: 0, y: kTopY),
            endPoint:   CGPoint(x: w, y: kBotY)
        ))

        // Highlight rim
        var hl = ctx; hl.opacity = 0.20
        hl.stroke(barPath, with: .color(.white), lineWidth: 1.0)

        // Subtle top gradient bead pattern
        var cl = ctx; cl.clip(to: barPath)
        let gold = Color(red: 0.98, green: 0.82, blue: 0.22)
        var bx: CGFloat = 28
        while bx < w - 20 {
            var gb = cl; gb.opacity = 0.18
            gb.fill(Path(ellipseIn: CGRect(x: bx-3, y: kTopY+4, width: 6, height: 6)), with: .color(gold))
            gb.fill(Path(ellipseIn: CGRect(x: bx-3, y: kBotY-10, width: 6, height: 6)), with: .color(gold))
            bx += 36
        }

        // Three hanging lanterns
        let positions: [(cx: CGFloat, phase: Double)] = [
            (w * 0.18, 0.00),
            (w * 0.50, 0.55),
            (w * 0.82, 1.10),
        ]
        for (cx, phase) in positions {
            let swing = CGFloat(sin(t * 0.75 + phase * .pi) * 5)
            let lx    = cx + swing
            // Hanging cord
            var cord = Path()
            cord.move(to:    CGPoint(x: cx, y: kBotY))
            cord.addLine(to: CGPoint(x: lx, y: kBotY + 18))
            ctx.stroke(cord, with: .color(gold.opacity(0.65)), lineWidth: 1.2)
            // Lantern body
            drawLantern(ctx: ctx, cx: lx, topY: kBotY + 16, bodySize: 44, t: t + phase)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 清明 — 有机波浪底边（如流水）+ 柳枝 + 花瓣
    // ─────────────────────────────────────────────────────────────────────────

    static func qingming(ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width
        let cR: CGFloat = 14

        // Shape: standard top corners, flowing wave at bottom
        var body = Path()
        body.move(to:    CGPoint(x: cR, y: kTopY))
        body.addLine(to: CGPoint(x: w - cR, y: kTopY))
        body.addQuadCurve(to: CGPoint(x: w, y: kTopY + cR), control: CGPoint(x: w, y: kTopY))
        // right side down to wave start
        body.addLine(to: CGPoint(x: w, y: kBotY - 16))
        // wave: flowing bezier from right to left
        body.addCurve(
            to:       CGPoint(x: w * 0.67, y: kBotY + 14),
            control1: CGPoint(x: w * 0.90, y: kBotY - 4),
            control2: CGPoint(x: w * 0.78, y: kBotY + 18)
        )
        body.addCurve(
            to:       CGPoint(x: w * 0.33, y: kBotY - 10),
            control1: CGPoint(x: w * 0.56, y: kBotY + 10),
            control2: CGPoint(x: w * 0.44, y: kBotY - 14)
        )
        body.addCurve(
            to:       CGPoint(x: 0, y: kBotY - 16),
            control1: CGPoint(x: w * 0.22, y: kBotY - 6),
            control2: CGPoint(x: w * 0.10, y: kBotY - 4)
        )
        body.addLine(to: CGPoint(x: 0, y: kTopY + cR))
        body.addQuadCurve(to: CGPoint(x: cR, y: kTopY), control: CGPoint(x: 0, y: kTopY))
        body.closeSubpath()

        // Misty forest gradient
        ctx.fill(body, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.08, green: 0.26, blue: 0.11),
                Color(red: 0.16, green: 0.42, blue: 0.18),
            ]),
            startPoint: CGPoint(x: 0, y: kTopY),
            endPoint:   CGPoint(x: w, y: kBotY)
        ))

        var cl = ctx; cl.clip(to: body)

        // Willow strands
        let wGreen = Color(red: 0.42, green: 0.78, blue: 0.36)
        for i in 0..<8 {
            let bx   = w * CGFloat(i) / 7.0
            let sway = CGFloat(sin(t * 0.50 + Double(i) * 1.12) * 9)
            var p = Path()
            p.move(to: CGPoint(x: bx, y: kTopY))
            p.addCurve(
                to:       CGPoint(x: bx + sway, y: kBotY - 5),
                control1: CGPoint(x: bx + sway * 0.18, y: kTopY + kBodyH * 0.28),
                control2: CGPoint(x: bx + sway * 0.68, y: kTopY + kBodyH * 0.62)
            )
            var gc = cl; gc.opacity = 0.16
            gc.stroke(p, with: .color(wGreen), lineWidth: 1.4)
        }

        // Drifting petals
        let petal = Color(red: 0.95, green: 0.80, blue: 0.85)
        for i in 0..<8 {
            let seed  = Double(i) * 4.17
            let phase = (t * 0.15 + seed * 0.10).truncatingRemainder(dividingBy: 1.0)
            let px    = (sin(seed * 2.03) * 0.38 + 0.5) * w + CGFloat(sin(t * 0.40 + seed) * 9)
            let py    = kTopY + kBodyH * CGFloat(phase)
            let alpha = min(phase * 3.5, (1.0 - phase) * 3.0, 0.48)
            var gc    = cl; gc.opacity = alpha
            gc.fill(Path(ellipseIn: CGRect(x: px-5, y: py-2.5, width: 10, height: 5)), with: .color(petal))
        }

        // Wave border highlight
        var bo = ctx; bo.opacity = 0.30
        bo.stroke(body, with: .color(Color(red: 0.58, green: 0.90, blue: 0.48)), lineWidth: 1.0)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 中秋 — 深空胶囊横幅 + 月亮从右上方探出
    // ─────────────────────────────────────────────────────────────────────────

    static func midAutumn(ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = size.width

        // Main banner: pill/oval shape
        let barPath = Path(roundedRect: CGRect(x: 0, y: kTopY, width: w, height: kBodyH), cornerRadius: kBodyH / 2)

        // Deep indigo night sky
        ctx.fill(barPath, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.03, green: 0.04, blue: 0.18),
                Color(red: 0.07, green: 0.10, blue: 0.32),
            ]),
            startPoint: CGPoint(x: 0, y: kTopY),
            endPoint:   CGPoint(x: w, y: kBotY)
        ))

        // Moon: center in the upper-right, partially above the banner
        let moonR:  CGFloat = 55
        let moonCX: CGFloat = w - moonR - 25
        let moonCY: CGFloat = kTopY - 18   // bleeds above banner into transparent zone

        // Glow rings drawn before clipping so they show outside the pill
        let moonGold = Color(red: 0.96, green: 0.82, blue: 0.32)
        for layer in 0..<5 {
            let extra  = CGFloat(layer) * 13
            let pulse  = CGFloat(0.055 + 0.020 * sin(t * 0.55 + Double(layer) * 0.38))
            var gc     = ctx; gc.opacity = Double(pulse) * Double(5 - layer) / 5.0
            gc.fill(
                Path(ellipseIn: CGRect(
                    x: moonCX - moonR - extra, y: moonCY - moonR - extra,
                    width: (moonR + extra) * 2, height: (moonR + extra) * 2
                )),
                with: .color(moonGold)
            )
        }

        // Moon body
        ctx.fill(
            Path(ellipseIn: CGRect(x: moonCX - moonR, y: moonCY - moonR, width: moonR*2, height: moonR*2)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.99, green: 0.95, blue: 0.82),
                    Color(red: 0.96, green: 0.85, blue: 0.54),
                ]),
                startPoint: CGPoint(x: moonCX - moonR, y: moonCY - moonR),
                endPoint:   CGPoint(x: moonCX + moonR, y: moonCY + moonR)
            )
        )

        // Subtle crater markings
        var shade = ctx; shade.opacity = 0.11
        shade.fill(Path(ellipseIn: CGRect(x: moonCX + 10, y: moonCY - 12, width: 16, height: 11)), with: .color(Color(red: 0.52, green: 0.40, blue: 0.18)))
        shade.fill(Path(ellipseIn: CGRect(x: moonCX - 18, y: moonCY + 10, width: 10, height: 7)), with: .color(Color(red: 0.52, green: 0.40, blue: 0.18)))
        shade.fill(Path(ellipseIn: CGRect(x: moonCX - 4,  y: moonCY - 22, width: 7,  height: 5)), with: .color(Color(red: 0.52, green: 0.40, blue: 0.18)))

        // Stars inside the banner pill
        var cl = ctx; cl.clip(to: barPath)
        let starData: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.07, 0.28, 2.6, 0.0), (0.14, 0.72, 2.0, 1.3),
            (0.25, 0.18, 1.8, 2.2), (0.36, 0.65, 2.3, 0.8),
            (0.48, 0.38, 1.6, 1.7), (0.58, 0.72, 2.0, 0.3),
            (0.38, 0.50, 1.4, 2.5),
        ]
        for (fx, fy, r, ph) in starData {
            let twinkle = 0.30 + 0.35 * sin(t * 1.05 + ph)
            var sc = cl; sc.opacity = twinkle
            sc.fill(eightPointStar(cx: fx * w, cy: kTopY + kBodyH * fy, r: CGFloat(r)), with: .color(.white))
        }

        // Banner rim
        var bo = ctx; bo.opacity = 0.20
        bo.stroke(barPath, with: .color(Color(red: 0.95, green: 0.84, blue: 0.50)), lineWidth: 1.0)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 圣诞 — 燕尾旗形状（右端V形剪口）+ 雪花 + 落雪
    // ─────────────────────────────────────────────────────────────────────────

    static func christmas(ctx: GraphicsContext, size: CGSize, t: Double) {
        let w      = size.width
        let notch: CGFloat = 36   // V-notch depth on right end
        let cR:    CGFloat = 10

        // Swallowtail/pennant shape: left side rounded, right side tapers to a point
        var body = Path()
        body.move(to:    CGPoint(x: cR, y: kTopY))
        body.addLine(to: CGPoint(x: w - notch, y: kTopY))
        body.addLine(to: CGPoint(x: w, y: kMidY))            // right tip →
        body.addLine(to: CGPoint(x: w - notch, y: kBotY))
        body.addLine(to: CGPoint(x: cR, y: kBotY))
        body.addQuadCurve(to: CGPoint(x: 0, y: kBotY - cR), control: CGPoint(x: 0, y: kBotY))
        body.addLine(to:    CGPoint(x: 0, y: kTopY + cR))
        body.addQuadCurve(to: CGPoint(x: cR, y: kTopY),     control: CGPoint(x: 0, y: kTopY))
        body.closeSubpath()

        // Deep forest green
        ctx.fill(body, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.04, green: 0.18, blue: 0.07),
                Color(red: 0.09, green: 0.30, blue: 0.12),
            ]),
            startPoint: CGPoint(x: 0, y: kTopY),
            endPoint:   CGPoint(x: w, y: kBotY)
        ))

        var cl = ctx; cl.clip(to: body)

        // Thin red ribbon stripes (horizontal accent lines)
        let xmasRed = Color(red: 0.68, green: 0.08, blue: 0.10)
        for lineY in [kTopY + 12, kBotY - 12] {
            var lp = Path()
            lp.move(to:    CGPoint(x: 0, y: lineY))
            lp.addLine(to: CGPoint(x: w - notch - 10, y: lineY))
            var lc = cl; lc.opacity = 0.35
            lc.stroke(lp, with: .color(xmasRed), lineWidth: 2.5)
        }

        // Geometric snowflakes at key positions
        let flakeData: [(CGFloat, CGFloat, CGFloat)] = [
            (0.07, 0.50, 13), (0.20, 0.25, 9), (0.35, 0.72, 8),
            (0.52, 0.30, 10), (0.68, 0.65, 8),
        ]
        for (fx, fy, r) in flakeData {
            drawSnowflake(ctx: cl, cx: fx * w, cy: kTopY + kBodyH * fy, r: CGFloat(r), t: t)
        }

        // Falling snow
        for i in 0..<12 {
            let seed  = Double(i) * 4.53
            let phase = (t * 0.24 + seed * 0.08).truncatingRemainder(dividingBy: 1.0)
            let px    = (sin(seed * 2.01) * 0.35 + 0.45) * (w - notch)
            let py    = kTopY + kBodyH * CGFloat(phase)
            let r     = CGFloat(1.3 + sin(seed * 2.4) * 0.9)
            let alpha = min(phase * 4, (1.0 - phase) * 3.5, 0.55)
            var gc    = cl; gc.opacity = alpha
            gc.fill(Path(ellipseIn: CGRect(x: px-r, y: py-r, width: r*2, height: r*2)), with: .color(.white))
        }

        // Gold border
        ctx.stroke(body, with: .color(Color(red: 0.88, green: 0.70, blue: 0.18).opacity(0.65)), lineWidth: 1.5)

        // Pulsing gold star at the right tip
        let pulse = CGFloat(0.70 + 0.30 * sin(t * 2.2))
        var sc    = ctx; sc.opacity = Double(pulse) * 0.85
        sc.fill(fivePointStar(cx: w - 6, cy: kMidY, r: 11), with: .color(Color(red: 0.97, green: 0.90, blue: 0.30)))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Shared helpers
    // ─────────────────────────────────────────────────────────────────────────

    private static func hexBanner(w: CGFloat, topY: CGFloat, botY: CGFloat,
                                  midY: CGFloat, pW: CGFloat, cR: CGFloat) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: pW + cR, y: topY))
        p.addLine(to: CGPoint(x: w - pW - cR, y: topY))
        p.addQuadCurve(to: CGPoint(x: w - pW, y: topY + cR), control: CGPoint(x: w - pW, y: topY))
        p.addLine(to: CGPoint(x: w, y: midY))               // right tip
        p.addLine(to: CGPoint(x: w - pW, y: botY - cR))
        p.addQuadCurve(to: CGPoint(x: w - pW - cR, y: botY), control: CGPoint(x: w - pW, y: botY))
        p.addLine(to: CGPoint(x: pW + cR, y: botY))
        p.addQuadCurve(to: CGPoint(x: pW, y: botY - cR),    control: CGPoint(x: pW, y: botY))
        p.addLine(to: CGPoint(x: 0, y: midY))               // left tip
        p.addLine(to: CGPoint(x: pW, y: topY + cR))
        p.addQuadCurve(to: CGPoint(x: pW + cR, y: topY),    control: CGPoint(x: pW, y: topY))
        p.closeSubpath()
        return p
    }

    private static func diamond(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: cx,   y: cy - r))
        p.addLine(to: CGPoint(x: cx+r, y: cy))
        p.addLine(to: CGPoint(x: cx,   y: cy + r))
        p.addLine(to: CGPoint(x: cx-r, y: cy))
        p.closeSubpath()
        return p
    }

    private static func eightPointStar(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        var p = Path()
        for i in 0..<8 {
            let angle  = Double(i) * .pi / 4 - .pi / 2
            let radius = i % 2 == 0 ? r : r * 0.42
            let pt = CGPoint(x: cx + CGFloat(cos(angle)) * radius,
                             y: cy + CGFloat(sin(angle)) * radius)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }

    private static func fivePointStar(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        var p = Path()
        for i in 0..<10 {
            let angle  = Double(i) * .pi / 5 - .pi / 2
            let radius = i % 2 == 0 ? r : r * 0.40
            let pt = CGPoint(x: cx + CGFloat(cos(angle)) * radius,
                             y: cy + CGFloat(sin(angle)) * radius)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }

    private static func drawSnowflake(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, t: Double) {
        let rot = t * 0.10
        var gc  = ctx; gc.opacity = 0.24
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 + rot
            let ex = cx + CGFloat(cos(angle)) * r
            let ey = cy + CGFloat(sin(angle)) * r
            var arm = Path()
            arm.move(to:    CGPoint(x: cx, y: cy))
            arm.addLine(to: CGPoint(x: ex, y: ey))
            for j in 1...2 {
                let bf  = CGFloat(j) / 3.0
                let bx  = cx + CGFloat(cos(angle)) * r * bf
                let by  = cy + CGFloat(sin(angle)) * r * bf
                let br  = r * 0.36
                for sign in [-1.0, 1.0] {
                    let ba = angle + sign * .pi / 4
                    arm.move(to:    CGPoint(x: bx, y: by))
                    arm.addLine(to: CGPoint(x: bx + CGFloat(cos(ba)) * br,
                                            y: by + CGFloat(sin(ba)) * br))
                }
            }
            gc.stroke(arm, with: .color(.white), lineWidth: 1.2)
        }
        var cc = ctx; cc.opacity = 0.32
        cc.fill(Path(ellipseIn: CGRect(x: cx-1.5, y: cy-1.5, width: 3, height: 3)), with: .color(.white))
    }

    private static func drawLantern(ctx: GraphicsContext, cx: CGFloat, topY: CGFloat,
                                    bodySize s: CGFloat, t: Double) {
        let gold    = Color(red: 1.00, green: 0.82, blue: 0.24)
        let red     = Color(red: 0.80, green: 0.07, blue: 0.05)
        let darkRed = Color(red: 0.48, green: 0.03, blue: 0.02)

        // Top cap
        ctx.fill(
            Path(roundedRect: CGRect(x: cx - s*0.38, y: topY, width: s*0.76, height: 7), cornerRadius: 2),
            with: .color(gold)
        )

        // Body ellipse
        let bodyR = CGRect(x: cx - s*0.44, y: topY + 6, width: s*0.88, height: s)
        ctx.fill(Path(ellipseIn: bodyR), with: .linearGradient(
            Gradient(colors: [Color(red: 0.90, green: 0.10, blue: 0.06), red]),
            startPoint: CGPoint(x: cx - s*0.44, y: topY + 6),
            endPoint:   CGPoint(x: cx + s*0.44, y: topY + 6 + s)
        ))

        // Vertical ribs
        for j in -1...1 {
            var rib = Path()
            let rx = cx + CGFloat(j) * s * 0.22
            rib.move(to:    CGPoint(x: rx, y: topY + 6))
            rib.addLine(to: CGPoint(x: rx, y: topY + 6 + s))
            var rc = ctx; rc.opacity = 0.30
            rc.stroke(rib, with: .color(darkRed), lineWidth: 1.5)
        }

        // Inner glow
        let pulse = CGFloat(0.22 + 0.10 * sin(t * 1.35))
        var gc    = ctx; gc.opacity = Double(pulse)
        gc.fill(
            Path(ellipseIn: CGRect(x: cx - s*0.20, y: topY + s*0.28, width: s*0.40, height: s*0.46)),
            with: .color(Color(red: 1.0, green: 0.58, blue: 0.12))
        )

        // Bottom cap
        ctx.fill(
            Path(roundedRect: CGRect(x: cx - s*0.38, y: topY + 6 + s - 3, width: s*0.76, height: 7), cornerRadius: 2),
            with: .color(gold)
        )

        // Tassels
        for k in -1...1 {
            var tassel = Path()
            let tx = cx + CGFloat(k) * s * 0.16
            let ty = topY + 6 + s + 4
            tassel.move(to:    CGPoint(x: tx, y: ty))
            tassel.addLine(to: CGPoint(x: tx + CGFloat(k) * 1.5, y: ty + 16))
            ctx.stroke(tassel, with: .color(gold.opacity(0.80)), lineWidth: 1.2)
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
                    .fill(prominent ? accent.opacity(0.42) : Color.white.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(prominent ? accent.opacity(0.68) : Color.white.opacity(0.20), lineWidth: 0.8)
                    )
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
