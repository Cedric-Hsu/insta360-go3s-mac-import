import AppKit
import SwiftUI

/// Ensures the main window supports resize and zoom (green traffic-light button).
private struct MainWindowConfigurator: NSViewRepresentable {
    let minSize: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                apply(to: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                apply(to: window)
            }
        }
    }

    private func apply(to window: NSWindow) {
        window.styleMask.insert([.resizable, .miniaturizable, .closable])
        window.collectionBehavior.formUnion([.fullScreenPrimary, .fullScreenAllowsTiling])
        if window.minSize != minSize {
            window.minSize = minSize
        }
    }
}

extension View {
    func configureMainWindow(minWidth: CGFloat = 1120, minHeight: CGFloat = 700) -> some View {
        background(
            MainWindowConfigurator(minSize: NSSize(width: minWidth, height: minHeight))
        )
    }
}
