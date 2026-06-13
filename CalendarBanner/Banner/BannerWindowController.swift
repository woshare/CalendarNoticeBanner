import AppKit
import SwiftUI

final class BannerWindowController {
    private var panels: [NSPanel] = []
    private let preferences: PreferencesStore

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    func show(event: CalendarEvent, minutesBefore: Int) {
        guard let screen = screenForBanner() else { return }

        let width = Self.bannerWidth(forScreenWidth: screen.frame.width)
        let height: CGFloat = 64
        let y = Self.bannerY(
            screenHeight: screen.frame.height,
            verticalPosition: preferences.verticalPosition
        ) + CGFloat(panels.count) * (height + 16)

        let panel = makePanel(width: width, height: height)
        let hostingView = NSHostingView(rootView: BannerView(
            event: event,
            minutesBefore: minutesBefore,
            preferences: preferences,
            onClose: { [weak panel, weak self] in
                guard let panel = panel else { return }
                self?.dismiss(panel: panel)
            }
        ))
        panel.contentView = hostingView

        let startX = screen.frame.minX - width
        let centerX = screen.frame.minX + (screen.frame.width - width) / 2
        let endX = screen.frame.maxX

        panel.setFrameOrigin(NSPoint(x: startX, y: screen.frame.minY + y))
        panel.orderFrontRegardless()
        panels.append(panel)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(NSPoint(x: centerX, y: screen.frame.minY + y))
        } completionHandler: { [weak self, weak panel] in
            guard let panel = panel else { return }
            let duration = self?.preferences.bannerDuration ?? 5.0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self?.animateOut(panel: panel, toX: endX)
            }
        }
    }

    private func animateOut(panel: NSPanel, toX: CGFloat) {
        var frame = panel.frame
        frame.origin.x = toX
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(frame.origin)
        } completionHandler: { [weak self, weak panel] in
            guard let panel = panel else { return }
            self?.remove(panel: panel)
        }
    }

    private func dismiss(panel: NSPanel) {
        let screen = NSScreen.screens.first { $0.frame.contains(panel.frame.origin) } ?? NSScreen.main ?? NSScreen.screens[0]
        animateOut(panel: panel, toX: screen.frame.maxX)
    }

    private func remove(panel: NSPanel) {
        panel.orderOut(nil)
        panels.removeAll { $0 === panel }
    }

    private func makePanel(width: CGFloat, height: CGFloat) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func screenForBanner() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    static func bannerWidth(forScreenWidth screenWidth: CGFloat) -> CGFloat {
        min(600, max(400, screenWidth * 0.5))
    }

    static func bannerY(screenHeight: CGFloat, verticalPosition: Double) -> CGFloat {
        screenHeight * CGFloat(verticalPosition)
    }

    static func verticalOffsets(forCount count: Int, bannerHeight: CGFloat, spacing: CGFloat) -> [CGFloat] {
        (0..<count).map { CGFloat($0) * (bannerHeight + spacing) }
    }
}
