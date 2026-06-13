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
        if toStart > 5 * 60 {
            return "\(Int(toStart / 60)) 分钟后"
        }
        let m = Int(toStart) / 60
        let s = Int(toStart) % 60
        return "\(m)分\(String(format: "%02d", s))秒"
    }

    var body: some View {
        ZStack {
            VisualEffectBlur()
                .cornerRadius(14)

            HStack(spacing: 0) {
                // 左侧颜色条
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(event.calendarColor))
                    .frame(width: 4, height: 48)
                    .padding(.leading, 14)

                HStack(spacing: 14) {
                    // 左中：会议信息（点击打开日历）
                    Button {
                        onOpen?()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                if preferences.showLocation, let location = event.location {
                                    Label(location, systemImage: "location.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                if preferences.showAttendeeCount, event.attendeeCount > 0 {
                                    Label("\(event.attendeeCount)人", systemImage: "person.2.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    Spacer()

                    // 右侧：时间 + 倒计时
                    VStack(alignment: .trailing, spacing: 4) {
                        if preferences.showTime {
                            Text(timeString)
                                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                                .foregroundColor(.primary)
                        }
                        if preferences.showCountdown {
                            Text(countdownString)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(event.calendarColor))
                        }
                    }

                    // 进入按钮：始终打开日历详情
                    Button("进入") {
                        onOpen?()
                        onClose?()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(event.calendarColor))
                    .controlSize(.small)

                    // Snooze 按钮
                    Button {
                        onSnooze?()
                        onClose?()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("稍后提醒")

                    // 关闭按钮
                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 12)
                .padding(.trailing, 14)
            }
        }
        .onReceive(ticker) { now = $0 }
        .frame(height: 80)
    }
}

// MARK: - NSVisualEffectView 桥接

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
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
    .frame(width: 560)
    .padding()
    .background(Color.gray.opacity(0.3))
}
