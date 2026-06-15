import SwiftUI
import AppKit

struct MinimalBannerView: View {
    let event: CalendarEvent
    let minutesBefore: Int
    let onOpen: () -> Void
    let onClose: () -> Void
    let onSnooze: () -> Void

    @State private var timeText: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var accentColor: Color {
        Color(event.calendarColor)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(0.5), lineWidth: 1.5)
                )

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: 4)
                    .padding(.vertical, 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(timeText)
                            .font(.system(size: 12))
                            .foregroundColor(accentColor)
                        if let loc = event.location, !loc.isEmpty {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(loc)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Button("稍后") { onSnooze() }
                        .buttonStyle(MinimalActionButtonStyle(color: .secondary))

                    Button("打开") { onOpen() }
                        .buttonStyle(MinimalActionButtonStyle(color: accentColor))

                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
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

private struct MinimalActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(color == .secondary ? .secondary : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color == .secondary ? Color.secondary.opacity(0.15) : color)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
