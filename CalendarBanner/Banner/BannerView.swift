import SwiftUI
import AppKit

struct BannerView: View {
    let event: CalendarEvent
    let minutesBefore: Int
    let preferences: PreferencesStore
    var onClose: (() -> Void)?

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: event.startDate)
    }

    private var countdownString: String {
        minutesBefore == 1 ? "1分钟后" : "\(minutesBefore)分钟后"
    }

    var body: some View {
        ZStack {
            VisualEffectBlur()
                .cornerRadius(12)

            HStack(spacing: 12) {
                Circle()
                    .fill(Color(event.calendarColor))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if preferences.showLocation, let location = event.location {
                            Text(location)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        if preferences.showAttendeeCount, event.attendeeCount > 0 {
                            Text("· \(event.attendeeCount)人")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    if preferences.showTime {
                        Text(timeString)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    if preferences.showCountdown {
                        Text(countdownString)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if preferences.showURL, let url = event.url {
                    Button("加入") {
                        NSWorkspace.shared.open(url)
                        onClose?()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    onClose?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 64)
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

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
        preferences: PreferencesStore()
    )
    .frame(width: 500)
    .padding()
}
