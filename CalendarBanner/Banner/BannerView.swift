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
            // Dragon boat hull + oars (animated at 20 fps)
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    DragonBoatRenderer.draw(ctx: ctx, size: size, t: t)
                }
            }
            .allowsHitTesting(false)

            // Content layer — centered in the 80-pt body zone
            HStack(spacing: 0) {
                Spacer().frame(width: 48)   // tail clearance

                HStack(spacing: 12) {
                    // Event info (tap → open calendar)
                    Button {
                        onOpen?()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1.5, x: 0, y: 1)
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
                                .shadow(color: .black.opacity(0.5), radius: 1.5, x: 0, y: 1)
                        }
                        if preferences.showCountdown {
                            Text(countdownString)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.yellow)
                                .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 1)
                        }
                    }

                    // Action buttons
                    Button("进入") {
                        onOpen?()
                        onClose?()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.10, green: 0.35, blue: 0.15))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.90))
                    .clipShape(Capsule())

                    Button {
                        onSnooze?()
                        onClose?()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .help("稍后提醒")

                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(width: 68)   // dragon head clearance
            }
            .padding(.horizontal, 4)
            .frame(height: 80)
        }
        .onReceive(ticker) { now = $0 }
    }
}

// MARK: - Dragon Boat Canvas Renderer

enum DragonBoatRenderer {
    // Traditional dragon boat palette
    private static let hullGreen  = Color(red: 0.15, green: 0.50, blue: 0.21)
    private static let scaleGreen = Color(red: 0.09, green: 0.33, blue: 0.13)
    private static let headOrange = Color(red: 0.84, green: 0.37, blue: 0.09)
    private static let headDark   = Color(red: 0.58, green: 0.24, blue: 0.06)
    private static let oarBrown   = Color(red: 0.66, green: 0.42, blue: 0.20)

    static func draw(ctx: GraphicsContext, size: CGSize, t: Double) {
        let w      = size.width
        let h      = size.height
        let midY   = h / 2
        let oarH: CGFloat = 22            // oars extend this far above/below body
        let bodyTop = oarH
        let bodyBot = h - oarH

        let tailTipX:  CGFloat = 8
        let bodyLeft:  CGFloat = 44
        let headStart: CGFloat = w - 67

        drawHull(ctx: ctx, w: w, midY: midY, bodyTop: bodyTop, bodyBot: bodyBot,
                 tailTipX: tailTipX, bodyLeft: bodyLeft, headStart: headStart)
        drawHead(ctx: ctx, hx: headStart - 2, midY: midY, bodyTop: bodyTop, bodyBot: bodyBot)
        drawOars(ctx: ctx, t: t, bodyLeft: bodyLeft, headStart: headStart,
                 bodyTop: bodyTop, bodyBot: bodyBot, oarH: oarH)
    }

    // MARK: Hull

    private static func drawHull(
        ctx: GraphicsContext,
        w: CGFloat, midY: CGFloat,
        bodyTop: CGFloat, bodyBot: CGFloat,
        tailTipX: CGFloat, bodyLeft: CGFloat, headStart: CGFloat
    ) {
        // ── Main hull path ──────────────────────────────────────────────
        var hull = Path()
        hull.move(to: CGPoint(x: bodyLeft, y: bodyTop))
        // Top edge — gentle upward bow
        hull.addCurve(
            to: CGPoint(x: headStart, y: bodyTop),
            control1: CGPoint(x: w * 0.28, y: bodyTop - 6),
            control2: CGPoint(x: w * 0.60, y: bodyTop - 6)
        )
        // Right round (neck connecting to head)
        hull.addCurve(
            to: CGPoint(x: headStart, y: bodyBot),
            control1: CGPoint(x: headStart + 18, y: bodyTop),
            control2: CGPoint(x: headStart + 18, y: bodyBot)
        )
        // Bottom edge — gentle downward bow
        hull.addCurve(
            to: CGPoint(x: bodyLeft, y: bodyBot),
            control1: CGPoint(x: w * 0.60, y: bodyBot + 6),
            control2: CGPoint(x: w * 0.28, y: bodyBot + 6)
        )
        // Tail taper — pointed left end
        hull.addCurve(
            to: CGPoint(x: tailTipX, y: midY),
            control1: CGPoint(x: bodyLeft - 14, y: bodyBot),
            control2: CGPoint(x: tailTipX, y: midY + 18)
        )
        hull.addCurve(
            to: CGPoint(x: bodyLeft, y: bodyTop),
            control1: CGPoint(x: tailTipX, y: midY - 18),
            control2: CGPoint(x: bodyLeft - 14, y: bodyTop)
        )
        hull.closeSubpath()

        ctx.fill(hull, with: .color(hullGreen))

        // ── Scale texture (clipped inside hull) ─────────────────────────
        var clipped = ctx
        clipped.clip(to: hull)
        let sw: CGFloat = 22
        var sx = bodyLeft + 16.0
        let rows: [CGFloat] = [midY - 20, midY, midY + 20]
        while sx < headStart - 10 {
            for ry in rows {
                var arc = Path()
                arc.move(to: CGPoint(x: sx, y: ry))
                arc.addCurve(
                    to: CGPoint(x: sx + sw, y: ry),
                    control1: CGPoint(x: sx + sw * 0.3, y: ry - 9),
                    control2: CGPoint(x: sx + sw * 0.7, y: ry - 9)
                )
                clipped.stroke(arc, with: .color(scaleGreen.opacity(0.55)), lineWidth: 1.1)
            }
            sx += sw + 2
        }

        ctx.stroke(hull, with: .color(scaleGreen), lineWidth: 1.8)
    }

    // MARK: Dragon head

    private static func drawHead(
        ctx: GraphicsContext,
        hx: CGFloat, midY: CGFloat,
        bodyTop: CGFloat, bodyBot: CGFloat
    ) {
        // Head blob
        var head = Path()
        head.move(to: CGPoint(x: hx, y: bodyTop + 6))
        head.addCurve(
            to: CGPoint(x: hx + 50, y: midY - 6),
            control1: CGPoint(x: hx + 22, y: bodyTop - 6),
            control2: CGPoint(x: hx + 50, y: midY - 22)
        )
        head.addLine(to: CGPoint(x: hx + 54, y: midY + 6))
        head.addCurve(
            to: CGPoint(x: hx + 40, y: bodyBot - 5),
            control1: CGPoint(x: hx + 58, y: midY + 18),
            control2: CGPoint(x: hx + 50, y: bodyBot)
        )
        head.addCurve(
            to: CGPoint(x: hx, y: bodyBot - 6),
            control1: CGPoint(x: hx + 24, y: bodyBot + 6),
            control2: CGPoint(x: hx + 10, y: bodyBot + 2)
        )
        head.closeSubpath()
        ctx.fill(head, with: .color(headOrange))
        ctx.stroke(head, with: .color(headDark), lineWidth: 1.5)

        // Eye — white sclera + dark iris + highlight
        let eyeRect = CGRect(x: hx + 19, y: midY - 13, width: 13, height: 13)
        ctx.fill(Path(ellipseIn: eyeRect), with: .color(.white))
        ctx.fill(Path(ellipseIn: eyeRect.insetBy(dx: 3, dy: 3)), with: .color(.black))
        ctx.fill(Path(ellipseIn: CGRect(x: hx + 23, y: midY - 11, width: 3.5, height: 3.5)),
                 with: .color(.white.opacity(0.8)))

        // Horn
        var horn = Path()
        horn.move(to: CGPoint(x: hx + 16, y: bodyTop + 5))
        horn.addLine(to: CGPoint(x: hx + 8,  y: bodyTop - 17))
        horn.addLine(to: CGPoint(x: hx + 22, y: bodyTop - 4))
        ctx.fill(horn, with: .color(headOrange))
        ctx.stroke(horn, with: .color(headDark), lineWidth: 1)

        // Whiskers (yellow curving lines)
        for (i, wy) in [midY - 4.0, midY + 6.0].enumerated() {
            var wh = Path()
            wh.move(to: CGPoint(x: hx + 48, y: wy))
            let tipY = wy + (i == 0 ? -7.0 : 5.0)
            wh.addCurve(
                to: CGPoint(x: hx + 66, y: tipY),
                control1: CGPoint(x: hx + 54, y: wy - 5),
                control2: CGPoint(x: hx + 62, y: wy - 2)
            )
            ctx.stroke(wh, with: .color(.yellow.opacity(0.95)), lineWidth: 1.8)
        }
    }

    // MARK: Oars

    private static func drawOars(
        ctx: GraphicsContext,
        t: Double,
        bodyLeft: CGFloat, headStart: CGFloat,
        bodyTop: CGFloat, bodyBot: CGFloat,
        oarH: CGFloat
    ) {
        let oarXs: [CGFloat] = [
            bodyLeft + 36, bodyLeft + 96, bodyLeft + 156, bodyLeft + 216
        ]
        for (i, ox) in oarXs.enumerated() where ox < headStart - 28 {
            let stagger = Double(i) * .pi / 2.0
            let swing = CGFloat(sin(t * .pi * 1.8 + stagger) * 7.0)

            // Top oar
            let topTip = CGPoint(x: ox + swing * 0.55, y: bodyTop - oarH + 4)
            var topShaft = Path()
            topShaft.move(to: CGPoint(x: ox, y: bodyTop))
            topShaft.addLine(to: topTip)
            ctx.stroke(topShaft, with: .color(oarBrown), lineWidth: 4)
            let topBlade = CGRect(x: topTip.x - 7, y: topTip.y - 11, width: 15, height: 11)
            ctx.fill(Path(roundedRect: topBlade, cornerRadius: 2), with: .color(oarBrown))
            ctx.stroke(Path(roundedRect: topBlade, cornerRadius: 2),
                       with: .color(headDark.opacity(0.4)), lineWidth: 0.8)

            // Bottom oar (opposing phase)
            let botSwing = CGFloat(sin(t * .pi * 1.8 + stagger + .pi) * 7.0)
            let botTip = CGPoint(x: ox + botSwing * 0.55, y: bodyBot + oarH - 4)
            var botShaft = Path()
            botShaft.move(to: CGPoint(x: ox, y: bodyBot))
            botShaft.addLine(to: botTip)
            ctx.stroke(botShaft, with: .color(oarBrown), lineWidth: 4)
            let botBlade = CGRect(x: botTip.x - 7, y: botTip.y, width: 15, height: 11)
            ctx.fill(Path(roundedRect: botBlade, cornerRadius: 2), with: .color(oarBrown))
            ctx.stroke(Path(roundedRect: botBlade, cornerRadius: 2),
                       with: .color(headDark.opacity(0.4)), lineWidth: 0.8)
        }
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
        onOpen: { print("open calendar") }
    )
    .frame(width: 560, height: 124)
    .background(Color.gray.opacity(0.3))
}
