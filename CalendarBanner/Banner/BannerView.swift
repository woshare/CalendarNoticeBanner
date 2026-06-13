import SwiftUI
import AppKit

struct BannerView: View {
    let event: CalendarEvent
    let minutesBefore: Int
    let preferences: PreferencesStore
    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?
    var onSnooze: (() -> Void)?

    @State private var now: Date = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: event.startDate)
    }

    private var countdownString: String {
        let toStart = event.startDate.timeIntervalSince(now)
        let toEnd   = event.endDate.timeIntervalSince(now)
        if toEnd <= 0 { return "已结束" }
        if toStart <= 0 {
            let elapsed = Int(-toStart)
            return "已开始 \(elapsed / 60)m \(elapsed % 60)s"
        }
        if toStart > 5 * 60 { return "\(Int(toStart / 60)) 分钟后" }
        let m = Int(toStart) / 60
        let s = Int(toStart) % 60
        return "\(m)分\(String(format: "%02d", s))秒"
    }

    var body: some View {
        ZStack {
            // Animated dragon art layer (20 fps)
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    DragonRenderer.draw(ctx: ctx, size: size, t: t)
                }
            }
            .allowsHitTesting(false)

            // Content — sits in the 80-pt body zone, centered in the 124-pt panel
            HStack(spacing: 0) {
                Spacer().frame(width: 44)   // tail clearance

                HStack(spacing: 12) {
                    // Event info
                    Button { onOpen?() } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                if preferences.showLocation, let loc = event.location {
                                    Label(loc, systemImage: "location.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.9))
                                        .lineLimit(1)
                                }
                                if preferences.showAttendeeCount, event.attendeeCount > 0 {
                                    Label("\(event.attendeeCount)人", systemImage: "person.2.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    Spacer()

                    // Time & countdown
                    VStack(alignment: .trailing, spacing: 3) {
                        if preferences.showTime {
                            Text(timeString)
                                .font(.system(size: 14, weight: .bold).monospacedDigit())
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        }
                        if preferences.showCountdown {
                            Text(countdownString)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.92, blue: 0.30))
                                .shadow(color: .black.opacity(0.7), radius: 1, x: 0, y: 1)
                        }
                    }

                    // Action buttons
                    Button("进入") {
                        onOpen?()
                        onClose?()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.08, green: 0.30, blue: 0.12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Capsule())

                    Button { onSnooze?(); onClose?() } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .help("稍后提醒")

                    Button { onClose?() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(width: 72)   // dragon head clearance
            }
            .padding(.horizontal, 4)
            .frame(height: 80)
        }
        .onReceive(ticker) { now = $0 }
    }
}

// MARK: - Dragon Renderer

enum DragonRenderer {

    // MARK: Palette
    private static let bodyGreen1  = Color(red: 0.10, green: 0.48, blue: 0.18)   // deep green
    private static let bodyGreen2  = Color(red: 0.18, green: 0.62, blue: 0.26)   // mid green
    private static let scaleEdge   = Color(red: 0.06, green: 0.30, blue: 0.10)   // dark outline
    private static let scaleFill   = Color(red: 0.08, green: 0.38, blue: 0.14)   // filled scale
    private static let highlight   = Color(red: 0.35, green: 0.82, blue: 0.42)   // dorsal shine
    private static let goldSpine   = Color(red: 0.95, green: 0.78, blue: 0.15)   // gold
    private static let fireOrange  = Color(red: 0.92, green: 0.40, blue: 0.05)
    private static let fireRed     = Color(red: 0.75, green: 0.12, blue: 0.05)
    private static let fireYellow  = Color(red: 1.00, green: 0.85, blue: 0.10)
    private static let redAccent   = Color(red: 0.88, green: 0.12, blue: 0.12)
    private static let oarBrown    = Color(red: 0.62, green: 0.38, blue: 0.16)

    // MARK: Entry point

    static func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let w      = size.width
        let h      = size.height
        let midY   = h / 2
        let oarH: CGFloat = 22
        let bodyTop = oarH
        let bodyBot = h - oarH

        // Key x positions
        let tailTip:   CGFloat = 6
        let bodyLeft:  CGFloat = 38
        let headStart: CGFloat = w - 74

        let hull = buildHull(w: w, midY: midY, bodyTop: bodyTop, bodyBot: bodyBot,
                             tailTip: tailTip, bodyLeft: bodyLeft, headStart: headStart)

        // Draw back-to-front
        drawGlow(ctx: ctx, cx: headStart + 36, midY: midY, t: t)
        drawHullFill(ctx: ctx, hull: hull)
        drawScales(ctx: ctx, hull: hull, bodyLeft: bodyLeft, headStart: headStart,
                   midY: midY, bodyTop: bodyTop, bodyBot: bodyBot)
        drawRedBands(ctx: ctx, hull: hull, headStart: headStart, bodyTop: bodyTop, bodyBot: bodyBot)
        drawHighlight(ctx: ctx, hull: hull, bodyLeft: bodyLeft, headStart: headStart, bodyTop: bodyTop)
        drawSpineDots(ctx: ctx, bodyLeft: bodyLeft, headStart: headStart, bodyTop: bodyTop, t: t)
        ctx.stroke(hull, with: .color(scaleEdge), lineWidth: 2.2)
        drawFlames(ctx: ctx, tailTip: tailTip, bodyLeft: bodyLeft, midY: midY, t: t)
        drawOars(ctx: ctx, t: t, bodyLeft: bodyLeft, headStart: headStart,
                 bodyTop: bodyTop, bodyBot: bodyBot, oarH: oarH)
        drawDragonHead(ctx: ctx, cx: headStart + 34, midY: midY)
    }

    // MARK: Hull path

    private static func buildHull(
        w: CGFloat, midY: CGFloat, bodyTop: CGFloat, bodyBot: CGFloat,
        tailTip: CGFloat, bodyLeft: CGFloat, headStart: CGFloat
    ) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: bodyLeft, y: bodyTop))
        // Top edge — pronounced upward bow
        p.addCurve(
            to: CGPoint(x: headStart, y: bodyTop),
            control1: CGPoint(x: w * 0.26, y: bodyTop - 8),
            control2: CGPoint(x: w * 0.58, y: bodyTop - 8)
        )
        // Neck join (right end)
        p.addCurve(
            to: CGPoint(x: headStart, y: bodyBot),
            control1: CGPoint(x: headStart + 22, y: bodyTop),
            control2: CGPoint(x: headStart + 22, y: bodyBot)
        )
        // Bottom edge
        p.addCurve(
            to: CGPoint(x: bodyLeft, y: bodyBot),
            control1: CGPoint(x: w * 0.58, y: bodyBot + 8),
            control2: CGPoint(x: w * 0.26, y: bodyBot + 8)
        )
        // Tail taper
        p.addCurve(
            to: CGPoint(x: tailTip, y: midY),
            control1: CGPoint(x: bodyLeft - 16, y: bodyBot),
            control2: CGPoint(x: tailTip, y: midY + 20)
        )
        p.addCurve(
            to: CGPoint(x: bodyLeft, y: bodyTop),
            control1: CGPoint(x: tailTip, y: midY - 20),
            control2: CGPoint(x: bodyLeft - 16, y: bodyTop)
        )
        p.closeSubpath()
        return p
    }

    // MARK: Glow behind head

    private static func drawGlow(ctx: GraphicsContext, cx: CGFloat, midY: CGFloat, t: Double) {
        let pulse = CGFloat(0.18 + 0.06 * sin(t * 1.4))
        var g = ctx
        g.opacity = Double(pulse)
        g.fill(Path(ellipseIn: CGRect(x: cx - 42, y: midY - 42, width: 84, height: 84)),
               with: .color(Color.orange))
        g.opacity = Double(pulse * 0.6)
        g.fill(Path(ellipseIn: CGRect(x: cx - 28, y: midY - 28, width: 56, height: 56)),
               with: .color(Color.yellow))
    }

    // MARK: Hull fill (two-tone)

    private static func drawHullFill(ctx: GraphicsContext, hull: Path) {
        ctx.fill(hull, with: .color(bodyGreen1))
        // Upper-half lighter overlay for 3-D effect
        var top = ctx
        top.opacity = 0.45
        top.fill(hull, with: .color(bodyGreen2))
    }

    // MARK: Overlapping scale pattern

    private static func drawScales(
        ctx: GraphicsContext, hull: Path,
        bodyLeft: CGFloat, headStart: CGFloat, midY: CGFloat,
        bodyTop: CGFloat, bodyBot: CGFloat
    ) {
        var clipped = ctx
        clipped.clip(to: hull)

        let scaleW: CGFloat  = 20
        let scaleH: CGFloat  = 13
        let rowYs: [CGFloat] = [midY - 22, midY, midY + 22]

        var col = 0
        var sx = bodyLeft + 6.0
        while sx < headStart - 6 {
            let xOff: CGFloat = col % 2 == 0 ? 0 : scaleW * 0.5
            for ry in rowYs {
                var arc = Path()
                arc.addArc(
                    center: CGPoint(x: sx + xOff, y: ry + scaleH * 0.3),
                    radius: scaleW * 0.55,
                    startAngle: .degrees(200),
                    endAngle: .degrees(340),
                    clockwise: false
                )
                arc.closeSubpath()
                clipped.fill(arc, with: .color(scaleFill))
                clipped.stroke(arc, with: .color(scaleEdge.opacity(0.65)), lineWidth: 0.9)
            }
            sx += scaleW * 0.82
            col += 1
        }
    }

    // MARK: Red accent bands (traditional dragon boat decoration)

    private static func drawRedBands(
        ctx: GraphicsContext, hull: Path,
        headStart: CGFloat, bodyTop: CGFloat, bodyBot: CGFloat
    ) {
        var clipped = ctx
        clipped.clip(to: hull)
        // One red band near the neck
        let bx = headStart - 36
        var band = Path()
        band.move(to: CGPoint(x: bx - 8,  y: bodyTop))
        band.addLine(to: CGPoint(x: bx + 8,  y: bodyTop))
        band.addLine(to: CGPoint(x: bx + 8,  y: bodyBot))
        band.addLine(to: CGPoint(x: bx - 8,  y: bodyBot))
        band.closeSubpath()
        clipped.fill(band, with: .color(redAccent.opacity(0.38)))
    }

    // MARK: Dorsal highlight stripe

    private static func drawHighlight(
        ctx: GraphicsContext, hull: Path,
        bodyLeft: CGFloat, headStart: CGFloat, bodyTop: CGFloat
    ) {
        var clipped = ctx
        clipped.clip(to: hull)
        var shine = Path()
        shine.move(to: CGPoint(x: bodyLeft + 10, y: bodyTop + 3))
        shine.addCurve(
            to: CGPoint(x: headStart - 10, y: bodyTop + 3),
            control1: CGPoint(x: bodyLeft + 80, y: bodyTop - 2),
            control2: CGPoint(x: headStart - 80, y: bodyTop - 2)
        )
        shine.addLine(to: CGPoint(x: headStart - 10, y: bodyTop + 10))
        shine.addCurve(
            to: CGPoint(x: bodyLeft + 10, y: bodyTop + 10),
            control1: CGPoint(x: headStart - 80, y: bodyTop + 5),
            control2: CGPoint(x: bodyLeft + 80, y: bodyTop + 5)
        )
        shine.closeSubpath()
        clipped.fill(shine, with: .color(highlight.opacity(0.30)))
    }

    // MARK: Gold spine dots

    private static func drawSpineDots(
        ctx: GraphicsContext,
        bodyLeft: CGFloat, headStart: CGFloat, bodyTop: CGFloat, t: Double
    ) {
        var sx = bodyLeft + 30.0
        var idx = 0
        while sx < headStart - 15 {
            let pulse = CGFloat(0.8 + 0.2 * sin(t * 2.2 + Double(idx) * 0.7))
            let r: CGFloat = 4 * pulse
            let dot = CGRect(x: sx - r, y: bodyTop - r - 2, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: dot), with: .color(goldSpine.opacity(0.92)))
            ctx.stroke(Path(ellipseIn: dot), with: .color(Color(red: 0.70, green: 0.50, blue: 0.05)), lineWidth: 0.7)
            sx += 32
            idx += 1
        }
    }

    // MARK: Flame / fire tail

    private static func drawFlames(
        ctx: GraphicsContext,
        tailTip: CGFloat, bodyLeft: CGFloat, midY: CGFloat, t: Double
    ) {
        // Outer flame (orange)
        let flicker = CGFloat(sin(t * 4.1) * 3)
        var outer = Path()
        outer.move(to: CGPoint(x: tailTip, y: midY))
        outer.addCurve(
            to: CGPoint(x: tailTip - 18 + flicker, y: midY - 28),
            control1: CGPoint(x: tailTip - 8, y: midY - 10),
            control2: CGPoint(x: tailTip - 20, y: midY - 18)
        )
        outer.addCurve(
            to: CGPoint(x: tailTip - 8, y: midY + 28),
            control1: CGPoint(x: tailTip - 10 - flicker, y: midY - 5),
            control2: CGPoint(x: tailTip - 14, y: midY + 16)
        )
        outer.closeSubpath()
        ctx.fill(outer, with: .color(fireOrange.opacity(0.90)))

        // Middle flame (yellow-orange)
        let flicker2 = CGFloat(sin(t * 5.3 + 1.0) * 2)
        var mid2 = Path()
        mid2.move(to: CGPoint(x: tailTip, y: midY))
        mid2.addCurve(
            to: CGPoint(x: tailTip - 14 + flicker2, y: midY - 18),
            control1: CGPoint(x: tailTip - 6, y: midY - 8),
            control2: CGPoint(x: tailTip - 14, y: midY - 12)
        )
        mid2.addCurve(
            to: CGPoint(x: tailTip - 6, y: midY + 18),
            control1: CGPoint(x: tailTip - 8 - flicker2, y: midY),
            control2: CGPoint(x: tailTip - 10, y: midY + 10)
        )
        mid2.closeSubpath()
        ctx.fill(mid2, with: .color(fireYellow.opacity(0.80)))

        // Inner tip (deep red)
        var inner = Path()
        inner.move(to: CGPoint(x: tailTip, y: midY - 4))
        inner.addLine(to: CGPoint(x: tailTip - 10, y: midY - 10))
        inner.addLine(to: CGPoint(x: tailTip - 10, y: midY + 10))
        inner.addLine(to: CGPoint(x: tailTip, y: midY + 4))
        inner.closeSubpath()
        ctx.fill(inner, with: .color(fireRed.opacity(0.70)))
    }

    // MARK: Animated oars

    private static func drawOars(
        ctx: GraphicsContext, t: Double,
        bodyLeft: CGFloat, headStart: CGFloat,
        bodyTop: CGFloat, bodyBot: CGFloat, oarH: CGFloat
    ) {
        let oarXs: [CGFloat] = [
            bodyLeft + 40, bodyLeft + 105, bodyLeft + 170, bodyLeft + 235
        ]
        for (i, ox) in oarXs.enumerated() where ox < headStart - 30 {
            let phase  = Double(i) * .pi / 2.0
            let topSwing  = CGFloat(sin(t * .pi * 1.8 + phase) * 9)
            let botSwing  = CGFloat(sin(t * .pi * 1.8 + phase + .pi) * 9)   // opposite phase

            // Top oar
            let topTip = CGPoint(x: ox + topSwing * 0.55, y: bodyTop - oarH + 3)
            var ts = Path()
            ts.move(to: CGPoint(x: ox, y: bodyTop + 2))
            ts.addLine(to: topTip)
            ctx.stroke(ts, with: .color(oarBrown), lineWidth: 4.5)
            let topBlade = CGRect(x: topTip.x - 8, y: topTip.y - 13, width: 17, height: 13)
            ctx.fill(Path(roundedRect: topBlade, cornerRadius: 3), with: .color(oarBrown))
            ctx.stroke(Path(roundedRect: topBlade, cornerRadius: 3),
                       with: .color(scaleEdge.opacity(0.4)), lineWidth: 0.8)

            // Bottom oar
            let botTip = CGPoint(x: ox + botSwing * 0.55, y: bodyBot + oarH - 3)
            var bs = Path()
            bs.move(to: CGPoint(x: ox, y: bodyBot - 2))
            bs.addLine(to: botTip)
            ctx.stroke(bs, with: .color(oarBrown), lineWidth: 4.5)
            let botBlade = CGRect(x: botTip.x - 8, y: botTip.y, width: 17, height: 13)
            ctx.fill(Path(roundedRect: botBlade, cornerRadius: 3), with: .color(oarBrown))
            ctx.stroke(Path(roundedRect: botBlade, cornerRadius: 3),
                       with: .color(scaleEdge.opacity(0.4)), lineWidth: 0.8)
        }
    }

    // MARK: Dragon head emoji

    private static func drawDragonHead(ctx: GraphicsContext, cx: CGFloat, midY: CGFloat) {
        let resolved = ctx.resolve(
            Text("🐉").font(.system(size: 62))
        )
        ctx.draw(resolved, at: CGPoint(x: cx, y: midY - 4), anchor: .center)
    }
}

// MARK: - Preview

#Preview {
    BannerView(
        event: CalendarEvent(
            id: "preview",
            title: "产品评审会",
            startDate: Date().addingTimeInterval(300),
            endDate: Date().addingTimeInterval(3900),
            location: "腾讯会议 Room 123",
            url: URL(string: "https://zoom.us/j/123"),
            attendeeCount: 8,
            calendarColor: .systemBlue
        ),
        minutesBefore: 5,
        preferences: PreferencesStore(),
        onOpen: { print("open") }
    )
    .frame(width: 560, height: 124)
    .background(Color.black.opacity(0.2))
}
