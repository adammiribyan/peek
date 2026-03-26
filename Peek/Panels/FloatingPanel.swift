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
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow

        let hostingView = NSHostingView(rootView: content())
        hostingView.sizingOptions = [.intrinsicContentSize]
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

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            orderOut(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}
