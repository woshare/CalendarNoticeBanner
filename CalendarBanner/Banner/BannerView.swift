import SwiftUI
import AppKit

// MARK: - Layout constants shared by view + renderer

private enum Layout {
    static let headW:     CGFloat = 82     // dragon head section width
    static let tailW:     CGFloat = 56     // tail section width
    static let bodyH:     CGFloat = 80     // boat body height (content zone)
    static let oarExtra:  CGFloat = 25     // oars protrude this far above/below body
    static var panelH:    CGFloat { bodyH + oarExtra * 2 }  // 130 pt total panel height
}

// MARK: - BannerView

struct BannerView: View {
    let event: CalendarEvent
    let minutesBefore: Int
    let preferences: PreferencesStore
    var onOpen:   (() -> Void)?
    var onClose:  (() -> Void)?
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
            // ── Dragon boat art (animated, non-interactive) ──────────────
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    DragonBoatRenderer.draw(ctx: ctx, size: size, t: t)
                }
            }
            .allowsHitTesting(false)

            // ── Calendar event content (sits in the body section) ────────
            HStack(spacing: 0) {
                // Push content past the dragon tail (now on left)
                Spacer().frame(width: Layout.tailW + 8)

                HStack(spacing: 10) {
                    // Event info — tap to open Calendar
                    Button { onOpen?() } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                if preferences.showLocation, let loc = event.location {
                                    Label(loc, systemImage: "location.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.88))
                                        .lineLimit(1)
                                }
                                if preferences.showAttendeeCount, event.attendeeCount > 0 {
                                    Label("\(event.attendeeCount)人", systemImage: "person.2.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.88))
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
                                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                        }
                        if preferences.showCountdown {
                            Text(countdownString)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.90, blue: 0.25))
                                .shadow(color: .black.opacity(0.7), radius: 1)
                        }
                    }

                    // Buttons
                    Button("进入") { onOpen?(); onClose?() }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.08, green: 0.30, blue: 0.12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Capsule())

                    Button { onSnooze?(); onClose?() } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .help("稍后提醒")

                    Button { onClose?() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.90))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                }

                // Push content away from the dragon head (now on right)
                Spacer().frame(width: Layout.headW + 8)
            }
            .padding(.horizontal, 4)
            .frame(height: Layout.bodyH)          // content is 80 pt tall …
            .frame(maxHeight: .infinity)           // … centered in the 130-pt panel
        }
        .onReceive(ticker) { now = $0 }
    }
}

// MARK: - Dragon Boat Renderer

enum DragonBoatRenderer {

    // Palette — tuned to match reference: bright green hull, orange oars, gold rails
    private static let hullGreen   = Color(red: 0.16, green: 0.62, blue: 0.26)   // brighter green
    private static let hullDark    = Color(red: 0.06, green: 0.30, blue: 0.10)
    private static let hullLight   = Color(red: 0.28, green: 0.78, blue: 0.38)   // lighter highlight
    private static let scaleFill   = Color(red: 0.10, green: 0.46, blue: 0.18)   // less dark scales
    private static let gold        = Color(red: 0.97, green: 0.82, blue: 0.12)   // vivid gold
    private static let goldDark    = Color(red: 0.74, green: 0.54, blue: 0.04)
    private static let orange      = Color(red: 0.93, green: 0.48, blue: 0.08)   // warm orange tail
    private static let oarOrange   = Color(red: 0.91, green: 0.50, blue: 0.10)   // oar paddle orange
    private static let oarShaft    = Color(red: 0.75, green: 0.35, blue: 0.06)   // darker shaft

    // ── Entry point ────────────────────────────────────────────────────────

    static func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        var ctx  = ctx
        ctx.concatenate(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: size.width, ty: 0))

        let w    = size.width
        let h    = size.height
        let midY = h / 2

        let bodyTop:   CGFloat = Layout.oarExtra
        let bodyBot:   CGFloat = h - Layout.oarExtra
        let bodyLeft:  CGFloat = Layout.headW - 6
        let bodyRight: CGFloat = w - Layout.tailW + 6

        drawWaterSplash(ctx: ctx, size: size, t: t, bodyLeft: bodyLeft)
        drawGlowAura(ctx: ctx, t: t, left: bodyLeft, right: bodyRight, top: bodyTop, bot: bodyBot)
        drawBoatHull(ctx: ctx, left: bodyLeft, right: bodyRight,
                     top: bodyTop, bot: bodyBot, midY: midY)
        drawOars(ctx: ctx, t: t, left: bodyLeft, right: bodyRight,
                 top: bodyTop, bot: bodyBot)
        drawTail(ctx: ctx, t: t, bodyRight: bodyRight, midY: midY,
                 top: bodyTop, bot: bodyBot, rightEdge: w)
        drawDragonHead(ctx: ctx, midY: midY, t: t)
    }

    // ── 0. Rainbow water splash ────────────────────────────────────────────

    private static func drawWaterSplash(
        ctx: GraphicsContext, size: CGSize, t: Double, bodyLeft: CGFloat
    ) {
        let baseY = size.height - 2
        let splashCX = bodyLeft + 28
        let drops: [(Color, CGFloat, CGFloat)] = [
            (Color(red: 1.0, green: 0.28, blue: 0.28), -34, 0),
            (Color(red: 1.0, green: 0.60, blue: 0.08), -17, 8),
            (Color(red: 0.22, green: 0.80, blue: 0.30),  0, 12),
            (Color(red: 0.18, green: 0.55, blue: 1.00),  17, 8),
            (Color(red: 0.78, green: 0.26, blue: 1.00),  34, 0),
        ]
        for (i, (col, xOff, yBase)) in drops.enumerated() {
            let anim = CGFloat(sin(t * 2.8 + Double(i) * 0.55) * 4)
            let dx = splashCX + xOff
            let tipY = baseY - 28 - yBase - anim
            var drop = Path()
            drop.move(to: CGPoint(x: dx - 5, y: baseY))
            drop.addQuadCurve(to: CGPoint(x: dx, y: tipY),
                              control: CGPoint(x: dx - 13, y: baseY - 18))
            drop.addQuadCurve(to: CGPoint(x: dx + 5, y: baseY),
                              control: CGPoint(x: dx + 13, y: baseY - 18))
            drop.closeSubpath()
            var gc = ctx; gc.opacity = 0.75
            gc.fill(drop, with: .color(col))
        }
        // White foam at hull bottom
        var foam = ctx; foam.opacity = 0.22 + 0.10 * sin(t * 3.0)
        foam.stroke(Path { p in
            p.move(to: CGPoint(x: bodyLeft + 10, y: baseY))
            p.addLine(to: CGPoint(x: size.width - Layout.tailW - 10, y: baseY))
        }, with: .color(.white), lineWidth: 5)
    }

    // ── 0b. Outer glow aura around hull ───────────────────────────────────

    private static func drawGlowAura(
        ctx: GraphicsContext, t: Double,
        left: CGFloat, right: CGFloat,
        top: CGFloat, bot: CGFloat
    ) {
        let pulse = 0.85 + 0.15 * sin(t * 1.3)
        let passes: [(CGFloat, Double, Color)] = [
            (30, 0.07 * pulse, .white),
            (20, 0.10 * pulse, gold),
            (12, 0.16 * pulse, gold),
            (6,  0.22 * pulse, gold),
        ]
        for (e, alpha, col) in passes {
            let l = left  - e * 0.35
            let r = right + e * 0.35
            let t2 = top  - e
            let b2 = bot  + e
            var p = Path()
            p.move(to: CGPoint(x: l, y: t2))
            p.addCurve(to: CGPoint(x: r, y: t2),
                       control1: CGPoint(x: l + (r-l)*0.3, y: t2 - e * 0.6),
                       control2: CGPoint(x: l + (r-l)*0.7, y: t2 - e * 0.6))
            p.addLine(to: CGPoint(x: r, y: b2))
            p.addCurve(to: CGPoint(x: l, y: b2),
                       control1: CGPoint(x: l + (r-l)*0.7, y: b2 + e * 0.6),
                       control2: CGPoint(x: l + (r-l)*0.3, y: b2 + e * 0.6))
            p.closeSubpath()
            var gc = ctx; gc.opacity = alpha
            gc.fill(p, with: .color(col))
        }
    }

    // ── 1. Boat hull ──────────────────────────────────────────────────────

    private static func drawBoatHull(
        ctx: GraphicsContext,
        left: CGFloat, right: CGFloat,
        top: CGFloat,  bot: CGFloat, midY: CGFloat
    ) {
        var hull = Path()
        hull.move(to: CGPoint(x: left,  y: top))
        hull.addCurve(to: CGPoint(x: right, y: top),
                      control1: CGPoint(x: left  + (right-left)*0.3, y: top - 5),
                      control2: CGPoint(x: left  + (right-left)*0.7, y: top - 5))
        hull.addLine(to: CGPoint(x: right, y: bot))
        hull.addCurve(to: CGPoint(x: left, y: bot),
                      control1: CGPoint(x: left + (right-left)*0.7, y: bot + 5),
                      control2: CGPoint(x: left + (right-left)*0.3, y: bot + 5))
        hull.closeSubpath()

        // Radial gradient fill — bright center like reference image
        let cx = (left + right) / 2
        let brightGreen = Color(red: 0.32, green: 0.82, blue: 0.42)
        ctx.fill(hull, with: .radialGradient(
            Gradient(colors: [brightGreen, hullGreen]),
            center: CGPoint(x: cx, y: midY),
            startRadius: 0,
            endRadius: (right - left) * 0.55
        ))

        var clipped = ctx
        clipped.clip(to: hull)

        // Fish-scale texture
        let sw: CGFloat = 22
        var col = 0; var sx = left + 8.0
        let rows: [CGFloat] = [midY - 22, midY, midY + 22]
        while sx < right - 6 {
            let xOff: CGFloat = col % 2 == 0 ? 0 : sw * 0.5
            for ry in rows {
                var arc = Path()
                arc.addArc(center: CGPoint(x: sx + xOff, y: ry + 5),
                           radius: sw * 0.56,
                           startAngle: .degrees(198), endAngle: .degrees(342),
                           clockwise: false)
                arc.closeSubpath()
                clipped.fill(arc,   with: .color(scaleFill))
                clipped.stroke(arc, with: .color(hullDark.opacity(0.55)), lineWidth: 0.85)
            }
            sx += sw * 0.80; col += 1
        }

        // Gold top rail
        let railH: CGFloat = 8
        var topRail = Path()
        topRail.move(to: CGPoint(x: left, y: top))
        topRail.addCurve(to: CGPoint(x: right, y: top),
                         control1: CGPoint(x: left+(right-left)*0.3, y: top-5),
                         control2: CGPoint(x: left+(right-left)*0.7, y: top-5))
        topRail.addLine(to: CGPoint(x: right, y: top + railH))
        topRail.addCurve(to: CGPoint(x: left, y: top + railH),
                         control1: CGPoint(x: left+(right-left)*0.7, y: top+railH-5),
                         control2: CGPoint(x: left+(right-left)*0.3, y: top+railH-5))
        topRail.closeSubpath()
        clipped.fill(topRail, with: .color(gold))

        // Second gold accent stripe
        clipped.fill(Path(roundedRect:
            CGRect(x: left, y: top + railH + 4, width: right - left, height: 3),
                          cornerRadius: 1), with: .color(gold.opacity(0.55)))

        // Gold bottom rail
        var botRail = Path()
        botRail.move(to: CGPoint(x: left, y: bot - railH))
        botRail.addLine(to: CGPoint(x: right, y: bot - railH))
        botRail.addLine(to: CGPoint(x: right, y: bot))
        botRail.addCurve(to: CGPoint(x: left, y: bot),
                         control1: CGPoint(x: left+(right-left)*0.7, y: bot+5),
                         control2: CGPoint(x: left+(right-left)*0.3, y: bot+5))
        botRail.closeSubpath()
        clipped.fill(botRail, with: .color(gold))

        ctx.stroke(hull, with: .color(hullDark), lineWidth: 2.0)
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: left, y: top + railH))
            p.addCurve(to: CGPoint(x: right, y: top + railH),
                       control1: CGPoint(x: left+(right-left)*0.3, y: top+railH-5),
                       control2: CGPoint(x: left+(right-left)*0.7, y: top+railH-5))
        }, with: .color(goldDark), lineWidth: 1.2)
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: left, y: bot - railH))
            p.addLine(to: CGPoint(x: right, y: bot - railH))
        }, with: .color(goldDark), lineWidth: 1.2)
    }

    // ── 2. Animated oars ──────────────────────────────────────────────────

    private static func drawOars(
        ctx: GraphicsContext, t: Double,
        left: CGFloat, right: CGFloat,
        top: CGFloat,  bot: CGFloat
    ) {
        let oarH = Layout.oarExtra
        let oarXs: [CGFloat] = stride(from: left + 45, through: right - 35, by: 68).map { $0 }
        for (i, ox) in oarXs.enumerated() {
            let phase    = Double(i) * .pi / 2.0
            let topSwing = CGFloat(sin(t * .pi * 2.0 + phase) * 9)
            let botSwing = CGFloat(sin(t * .pi * 2.0 + phase + .pi) * 9)
            drawSingleOar(ctx: ctx, baseX: ox, baseY: top,
                          tipX: ox + topSwing * 0.6, tipY: top - oarH + 4, facingUp: true)
            drawSingleOar(ctx: ctx, baseX: ox, baseY: bot,
                          tipX: ox + botSwing * 0.6, tipY: bot + oarH - 4, facingUp: false)
        }
    }

    private static func drawSingleOar(
        ctx: GraphicsContext,
        baseX: CGFloat, baseY: CGFloat,
        tipX: CGFloat,  tipY: CGFloat,
        facingUp: Bool
    ) {
        var shaft = Path()
        shaft.move(to: CGPoint(x: baseX, y: baseY + (facingUp ? 2 : -2)))
        shaft.addLine(to: CGPoint(x: tipX, y: tipY + (facingUp ? 2 : -2)))
        ctx.stroke(shaft, with: .color(oarShaft), lineWidth: 5)

        let bladeH: CGFloat = 14, bladeW: CGFloat = 20
        let by = facingUp ? tipY - bladeH : tipY
        var blade = Path()
        blade.addRoundedRect(in: CGRect(x: tipX - bladeW/2, y: by, width: bladeW, height: bladeH),
                             cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(blade,   with: .color(oarOrange))
        ctx.stroke(blade, with: .color(oarShaft), lineWidth: 0.9)
        var hl = ctx; hl.opacity = 0.38
        hl.fill(Path(roundedRect: CGRect(x: tipX - bladeW/2 + 3, y: by + 3,
                                         width: bladeW - 6, height: 4),
                     cornerRadius: 1.5), with: .color(.white))
    }

    // ── 3. Dragon tail ────────────────────────────────────────────────────

    private static func drawTail(
        ctx: GraphicsContext, t: Double,
        bodyRight: CGFloat, midY: CGFloat,
        top: CGFloat, bot: CGFloat, rightEdge: CGFloat
    ) {
        let flicker = CGFloat(sin(t * 3.2) * 2.5)
        let finData: [(yOff: CGFloat, alpha: CGFloat, scale: CGFloat)] = [
            (-20, 0.95, 1.0),
            ( -4, 0.80, 0.85),
            ( 14, 0.65, 0.70),
        ]
        for (i, fin) in finData.enumerated() {
            let tipX = rightEdge - 4 + CGFloat(i) * 3
            let tipY = top - 24 + fin.yOff + flicker * 0.5 * CGFloat(3 - i)
            var path = Path()
            path.move(to: CGPoint(x: bodyRight, y: midY - 14 + fin.yOff * 0.4))
            path.addCurve(to: CGPoint(x: tipX, y: tipY),
                          control1: CGPoint(x: bodyRight + (rightEdge-bodyRight)*0.4,
                                            y: midY - 10 + fin.yOff * 0.3),
                          control2: CGPoint(x: bodyRight + (rightEdge-bodyRight)*0.75,
                                            y: tipY + 16))
            path.addCurve(to: CGPoint(x: bodyRight, y: midY + 14 + fin.yOff * 0.4),
                          control1: CGPoint(x: bodyRight + (rightEdge-bodyRight)*0.65,
                                            y: tipY + 26),
                          control2: CGPoint(x: bodyRight + (rightEdge-bodyRight)*0.35,
                                            y: midY + 12 + fin.yOff * 0.35))
            path.closeSubpath()
            ctx.fill(path,   with: .color(orange.opacity(fin.alpha * Double(fin.scale))))
            ctx.stroke(path, with: .color(goldDark.opacity(0.8)), lineWidth: 1.2)
            var edge = Path()
            edge.move(to: CGPoint(x: bodyRight, y: midY - 14 + fin.yOff * 0.4))
            edge.addCurve(to: CGPoint(x: tipX, y: tipY),
                          control1: CGPoint(x: bodyRight + (rightEdge-bodyRight)*0.4,
                                            y: midY - 10 + fin.yOff * 0.3),
                          control2: CGPoint(x: bodyRight + (rightEdge-bodyRight)*0.75,
                                            y: tipY + 16))
            ctx.stroke(edge, with: .color(gold.opacity(fin.alpha * 0.75)), lineWidth: 1.2)
        }
        var block = Path()
        block.move(to: CGPoint(x: bodyRight - 4, y: top))
        block.addLine(to: CGPoint(x: rightEdge - 18, y: top + 8))
        block.addLine(to: CGPoint(x: rightEdge - 18, y: bot - 8))
        block.addLine(to: CGPoint(x: bodyRight - 4, y: bot))
        block.closeSubpath()
        ctx.fill(block,   with: .color(hullGreen))
        ctx.stroke(block, with: .color(hullDark), lineWidth: 1.5)
        let connW = rightEdge - 18 - (bodyRight - 3)
        ctx.fill(Path(roundedRect: CGRect(x: bodyRight-3, y: top+2, width: connW, height: 7),
                      cornerRadius: 2), with: .color(gold))
        ctx.fill(Path(roundedRect: CGRect(x: bodyRight-3, y: bot-9, width: connW, height: 7),
                      cornerRadius: 2), with: .color(gold))
    }

    // ── 4. Dragon head ────────────────────────────────────────────────────

    private static func drawDragonHead(ctx: GraphicsContext, midY: CGFloat, t: Double) {
        let cx: CGFloat = Layout.headW / 2
        let wave = CGFloat(sin(t * 1.5) * 2.5)

        // Large pulsing glow behind head
        let pulse = 0.18 + 0.09 * sin(t * 1.7)
        var gCtx = ctx; gCtx.opacity = pulse
        gCtx.fill(Path(ellipseIn: CGRect(x: cx-52, y: midY-56, width: 104, height: 112)),
                  with: .color(gold))

        // ── Golden mane — 5 large teardrop petals ─────────────────────
        let petals: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            // tipX,        tipY,              baseX,   baseY,       halfW
            (cx - 40, midY - 54 + wave,        cx - 12, midY - 14,   9),
            (cx - 22, midY - 65 + wave,        cx -  5, midY - 12,  11),
            (cx -  2, midY - 59 + wave,        cx +  5, midY - 10,  10),
            (cx + 15, midY - 47 + wave * 0.7,  cx + 14, midY -  8,   8),
            (cx - 50, midY - 18 + wave * 0.5,  cx - 20, midY +  6,   7),
        ]
        for (tipX, tipY, bx, by, hw) in petals {
            let tip  = CGPoint(x: tipX, y: tipY)
            let bL   = CGPoint(x: bx - hw, y: by)
            let bR   = CGPoint(x: bx + hw, y: by - 4)
            let cL   = CGPoint(x: bL.x - 6, y: (bL.y + tipY) / 2)
            let cR   = CGPoint(x: bR.x + 6, y: (bR.y + tipY) / 2)
            var petal = Path()
            petal.move(to: bL)
            petal.addQuadCurve(to: tip,  control: cL)
            petal.addQuadCurve(to: bR,   control: cR)
            petal.closeSubpath()
            ctx.fill(petal,   with: .color(gold))
            ctx.stroke(petal, with: .color(goldDark), lineWidth: 0.9)
            // Inner lighter highlight
            let tipI = CGPoint(x: tipX + (bx-tipX)*0.28, y: tipY + (by-tipY)*0.28)
            var inner = Path()
            inner.move(to: CGPoint(x: bL.x+3, y: bL.y+2))
            inner.addQuadCurve(to: tipI, control: CGPoint(x: cL.x+2, y: cL.y))
            inner.addLine(to: CGPoint(x: bR.x-3, y: bR.y+2))
            inner.closeSubpath()
            var hl = ctx; hl.opacity = 0.42
            hl.fill(inner, with: .color(Color(red: 1.0, green: 0.96, blue: 0.55)))
        }

        // Neck connector
        let neckX = Layout.headW - 6.0
        var neck = Path()
        neck.move(to: CGPoint(x: neckX-4, y: midY - Layout.bodyH/2))
        neck.addCurve(to: CGPoint(x: neckX-4, y: midY + Layout.bodyH/2),
                      control1: CGPoint(x: neckX+8, y: midY - Layout.bodyH/2),
                      control2: CGPoint(x: neckX+8, y: midY + Layout.bodyH/2))
        neck.addLine(to: CGPoint(x: neckX+4, y: midY + Layout.bodyH/2))
        neck.addCurve(to: CGPoint(x: neckX+4, y: midY - Layout.bodyH/2),
                      control1: CGPoint(x: neckX+12, y: midY + Layout.bodyH/2),
                      control2: CGPoint(x: neckX+12, y: midY - Layout.bodyH/2))
        neck.closeSubpath()
        ctx.fill(neck, with: .color(hullGreen))

        // Dragon face emoji (mirrored by parent transform → faces right)
        let face = ctx.resolve(Text("🐲").font(.system(size: 72)))
        ctx.draw(face, at: CGPoint(x: cx, y: midY - 4), anchor: .center)
    }
}

// MARK: - Preview

#Preview {
    BannerView(
        event: CalendarEvent(
            id: "preview",
            title: "产品评审会 Q2",
            startDate: Date().addingTimeInterval(300),
            endDate: Date().addingTimeInterval(3900),
            location: "腾讯会议 888",
            url: nil,
            attendeeCount: 8,
            calendarColor: .systemBlue
        ),
        minutesBefore: 5,
        preferences: PreferencesStore(),
        onOpen: { }
    )
    .frame(width: 560, height: 130)
    .background(Color.gray.opacity(0.25))
}
