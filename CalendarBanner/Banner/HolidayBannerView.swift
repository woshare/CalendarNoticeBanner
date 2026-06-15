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
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.accentColor.opacity(0.6), lineWidth: 1.5)
                )

            Canvas { ctx, size in
                theme.drawDecorations(ctx, size, animTick)
            }
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.accentColor)
                    .frame(width: 4)
                    .padding(.vertical, 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textColor)
                        .lineLimit(1)
                    Text(timeLabel)
                        .font(.system(size: 12))
                        .foregroundColor(theme.accentColor)
                }

                Spacer()

                HStack(spacing: 6) {
                    Button("稍后") { onSnooze() }
                        .buttonStyle(HolidayButtonStyle(color: .secondary, theme: theme))
                    Button("打开") { onOpen() }
                        .buttonStyle(HolidayButtonStyle(color: theme.accentColor, theme: theme))
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.textColor.opacity(0.6))
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
    let backgroundColor: Color
    let accentColor: Color
    let textColor: Color
    let drawDecorations: (GraphicsContext, CGSize, Double) -> Void

    init(skin: BannerSkinID) {
        switch skin {
        case .springFestival:
            backgroundColor = Color(red: 0.75, green: 0.08, blue: 0.08)
            accentColor     = Color(red: 0.97, green: 0.82, blue: 0.12)
            textColor       = .white
            drawDecorations = HolidayDecorations.springFestival
        case .lanternFestival:
            backgroundColor = Color(red: 0.55, green: 0.06, blue: 0.06)
            accentColor     = Color(red: 1.0, green: 0.75, blue: 0.20)
            textColor       = .white
            drawDecorations = HolidayDecorations.lanternFestival
        case .qingming:
            backgroundColor = Color(red: 0.20, green: 0.42, blue: 0.20)
            accentColor     = Color(red: 0.60, green: 0.88, blue: 0.55)
            textColor       = .white
            drawDecorations = HolidayDecorations.qingming
        case .midAutumn:
            backgroundColor = Color(red: 0.07, green: 0.10, blue: 0.28)
            accentColor     = Color(red: 0.97, green: 0.85, blue: 0.45)
            textColor       = .white
            drawDecorations = HolidayDecorations.midAutumn
        case .christmas:
            backgroundColor = Color(red: 0.08, green: 0.28, blue: 0.12)
            accentColor     = Color(red: 0.92, green: 0.20, blue: 0.20)
            textColor       = .white
            drawDecorations = HolidayDecorations.christmas
        default:
            backgroundColor = Color(red: 0.16, green: 0.62, blue: 0.26)
            accentColor     = Color(red: 0.97, green: 0.82, blue: 0.12)
            textColor       = .white
            drawDecorations = { _, _, _ in }
        }
    }
}

// MARK: - Decorations

enum HolidayDecorations {

    static func springFestival(ctx: GraphicsContext, size: CGSize, t: Double) {
        let count = 12
        for i in 0..<count {
            let seed  = Double(i) * 7.3
            let phase = (t * 0.4 + seed).truncatingRemainder(dividingBy: 1.0)
            let x     = (sin(seed * 1.7) * 0.4 + 0.5) * size.width
            let y     = size.height * (1.0 - phase)
            let alpha = min(phase * 4, (1.0 - phase) * 3, 1.0)
            var gc = ctx; gc.opacity = alpha * 0.55
            gc.fill(
                Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                with: .color(Color(red: 0.97, green: 0.82, blue: 0.12))
            )
        }
    }

    static func lanternFestival(ctx: GraphicsContext, size: CGSize, t: Double) {
        let swing = CGFloat(sin(t * 1.2) * 6)
        drawLantern(ctx: ctx, cx: 30,              cy: 20 + swing, size: 18)
        drawLantern(ctx: ctx, cx: size.width - 30, cy: 20 - swing, size: 18)
    }

    static func qingming(ctx: GraphicsContext, size: CGSize, t: Double) {
        for i in 0..<5 {
            let x    = size.width * CGFloat(i) / 4.0
            let sway = CGFloat(sin(t * 0.8 + Double(i) * 0.9) * 4)
            var p = Path()
            p.move(to: CGPoint(x: x, y: 0))
            p.addCurve(
                to: CGPoint(x: x + sway, y: size.height * 0.6),
                control1: CGPoint(x: x + sway * 0.3, y: size.height * 0.2),
                control2: CGPoint(x: x + sway * 0.7, y: size.height * 0.4)
            )
            var gc = ctx; gc.opacity = 0.18
            gc.stroke(p, with: .color(Color(red: 0.60, green: 0.88, blue: 0.55)), lineWidth: 1.5)
        }
    }

    static func midAutumn(ctx: GraphicsContext, size: CGSize, t: Double) {
        let moonGlow = CGFloat(0.12 + 0.04 * sin(t * 0.8))
        var gc = ctx; gc.opacity = Double(moonGlow)
        gc.fill(
            Path(ellipseIn: CGRect(x: size.width - 50, y: -10, width: 60, height: 60)),
            with: .color(Color(red: 0.97, green: 0.85, blue: 0.45))
        )
        let stars: [(CGFloat, CGFloat)] = [(0.15,0.25),(0.30,0.10),(0.55,0.35),(0.70,0.15),(0.85,0.45)]
        for (i, (fx, fy)) in stars.enumerated() {
            let twinkle = 0.3 + 0.25 * sin(t * 1.5 + Double(i) * 2.1)
            var sc = ctx; sc.opacity = twinkle
            sc.fill(
                Path(ellipseIn: CGRect(x: fx * size.width - 2, y: fy * size.height - 2, width: 4, height: 4)),
                with: .color(.white)
            )
        }
    }

    static func christmas(ctx: GraphicsContext, size: CGSize, t: Double) {
        let count = 10
        for i in 0..<count {
            let seed  = Double(i) * 5.1
            let phase = (t * 0.25 + seed * 0.1).truncatingRemainder(dividingBy: 1.0)
            let x     = (sin(seed * 2.3) * 0.45 + 0.5) * size.width
            let y     = size.height * phase
            let alpha = min(phase * 3, (1.0 - phase) * 3, 0.7)
            var gc = ctx; gc.opacity = alpha
            gc.fill(
                Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                with: .color(.white)
            )
        }
    }

    private static func drawLantern(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, size: CGFloat) {
        let gold = Color(red: 1.0, green: 0.75, blue: 0.20)
        let red  = Color(red: 0.80, green: 0.08, blue: 0.08)
        var line = Path()
        line.move(to: CGPoint(x: cx, y: 0))
        line.addLine(to: CGPoint(x: cx, y: cy - size * 0.5))
        ctx.stroke(line, with: .color(gold.opacity(0.7)), lineWidth: 1)
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - size*0.4, y: cy - size*0.5, width: size*0.8, height: size)),
            with: .color(red)
        )
        ctx.fill(
            Path(roundedRect: CGRect(x: cx - size*0.3, y: cy - size*0.5 - 3, width: size*0.6, height: 5),
                 cornerRadius: 2),
            with: .color(gold)
        )
        ctx.fill(
            Path(roundedRect: CGRect(x: cx - size*0.3, y: cy + size*0.5 - 2, width: size*0.6, height: 5),
                 cornerRadius: 2),
            with: .color(gold)
        )
    }
}

// MARK: - Button Style

private struct HolidayButtonStyle: ButtonStyle {
    let color: Color
    let theme: HolidayTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(color == .secondary ? theme.textColor.opacity(0.6) : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color == .secondary ? Color.white.opacity(0.15) : color)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
