import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    convenience init<Content: View>(resizable: Bool = false, @ViewBuilder content: () -> Content) {
        var mask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView]
        if resizable {
            mask.insert(.titled)
            mask.insert(.resizable)
        } else {
            mask.insert(.borderless)
        }

        self.init(
            contentRect: .zero,
            styleMask: mask,
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

        if resizable {
            titlebarAppearsTransparent = true
            titleVisibility = .hidden
            titlebarSeparatorStyle = .none
            standardWindowButton(.closeButton)?.isHidden = true
            standardWindowButton(.miniaturizeButton)?.isHidden = true
            standardWindowButton(.zoomButton)?.isHidden = true
        }

        let hostingView = NSHostingView(rootView: content())
        hostingView.sizingOptions = [.intrinsicContentSize]
        contentView = hostingView

        setContentSize(hostingView.fittingSize)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    override func performClose(_ sender: Any?) {
        orderOut(nil)
    }

    override func keyDown(with event: NSEvent) {
        // Cmd+W closes the panel
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            orderOut(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
