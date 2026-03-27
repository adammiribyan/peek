import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    /// When true, the panel closes when it loses key window status (click outside).
    var dismissesOnResignKey = false

    convenience init<Content: View>(@ViewBuilder content: () -> Content) {
        self.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow

        let hostingView = NSHostingView(rootView: content().background(.clear))
        hostingView.sizingOptions = [.intrinsicContentSize]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        hostingView.layer?.cornerRadius = 16
        hostingView.layer?.masksToBounds = true
        contentView = hostingView

        setContentSize(hostingView.fittingSize)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        if dismissesOnResignKey {
            orderOut(nil)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    override func performClose(_ sender: Any?) {
        orderOut(nil)
    }

    var onOpenSettings: (() -> Void)?
    private var keyMonitor: Any?

    func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isKeyWindow else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == .command && event.charactersIgnoringModifiers == "," {
                self.onOpenSettings?()
                return nil
            }
            if mods == .command && event.charactersIgnoringModifiers == "w" {
                self.orderOut(nil)
                return nil
            }
            return event
        }
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }
}
