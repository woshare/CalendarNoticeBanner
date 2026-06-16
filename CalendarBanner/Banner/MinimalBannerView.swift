import SwiftUI
import AppKit

struct MinimalBannerView: View {
    let event: CalendarEvent
    let minutesBefore: Int
    let preferences: PreferencesStore
    let onOpen: () -> Void
    let onClose: () -> Void
    let onSnooze: () -> Void

    @State private var timeText: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Gradient from calendar color

    private var gradientColors: (Color, Color) {
        let ns = (event.calendarColor.usingColorSpace(.sRGB) ?? event.calendarColor)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let primary   = Color(hue: Double(h), saturation: Double(s),        brightness: Double(b))
        let h2        = (Double(h) + 28.0/360.0).truncatingRemainder(dividingBy: 1.0)
        let secondary = Color(hue: h2, saturation: max(0.25, Double(s) - 0.12), brightness: min(1.0, Double(b) + 0.22))
        return (primary, secondary)
    }

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

    var body: some View {
        let (c1, c2) = gradientColors
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [c1, c2],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )

            // Top highlight line — light source feel
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)

            // Content
            HStack(spacing: 12) {
                // Left accent bar — white semi-transparent
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.40))
                    .frame(width: 4)
                    .padding(.vertical, 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let endTime = endTimeString {
                            Text(endTime)
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .foregroundColor(.white.opacity(0.88))
                        } else {
                            Text(timeText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.88))
                        }
                        if let loc = event.location, !loc.isEmpty {
                            Text("·").foregroundColor(.white.opacity(0.5))
                            Text(loc)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.72))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Button("稍后") { onSnooze() }
                        .buttonStyle(GradientActionButtonStyle(prominent: false))

                    Button("打开") { onOpen() }
                        .buttonStyle(GradientActionButtonStyle(prominent: true))

                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: BannerLayout.bodyH)
        .onReceive(timer) { _ in updateTime() }
        .onAppear { updateTime() }
    }

    private func updateTime() {
        let mins = event.minutesUntilStart(from: Date())
        if mins > 1 {
            timeText = "\(Int(mins)) 分钟后"
        } else if mins > 0 {
            timeText = "即将开始"
        } else {
            timeText = "进行中"
        }
    }
}

private struct GradientActionButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(prominent ? .white : .white.opacity(0.80))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(prominent ? Color.white.opacity(0.28) : Color.white.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(prominent ? 0.45 : 0.20), lineWidth: 0.8)
                    )
            )
            .opacity(configuration.isPressed ? 0.70 : 1)
    }
}
