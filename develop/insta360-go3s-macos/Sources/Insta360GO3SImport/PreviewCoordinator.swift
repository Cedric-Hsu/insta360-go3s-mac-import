import AppKit
import AVKit
import QuickLookUI
import SwiftUI

enum CameraEndpoints {
    static let host = "192.168.42.1"
}

// MARK: - Quick Look (local files)

final class PreviewAppDelegate: NSObject, NSApplicationDelegate, QLPreviewPanelDataSource {
    static var previewURL: URL?

    static func showQuickLook(for url: URL) {
        previewURL = url
        guard let panel = QLPreviewPanel.shared(), panel.canBecomeKey else {
            return
        }
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    @objc override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        Self.previewURL != nil
    }

    @objc override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
    }

    @objc override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        Self.previewURL = nil
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        Self.previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard let url = Self.previewURL else { return nil }
        return url as NSURL
    }
}

// MARK: - Remote HTTP streaming

@MainActor
final class RemotePreviewSession: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let player: AVPlayer

    @Published var isLoading = true
    @Published var errorMessage: String?

    private var statusObservation: NSKeyValueObservation?

    init(url: URL, title: String) {
        self.url = url
        self.title = title
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        AppLogger.log("preview", "remote session start", extra: ["url": url.absoluteString, "title": title])
        observePlayerStatus()
    }

    func play() {
        player.play()
    }

    func cleanup() {
        AppLogger.log("preview", "remote session cleanup", extra: ["title": title])
        statusObservation?.invalidate()
        statusObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func observePlayerStatus() {
        guard let item = player.currentItem else {
            isLoading = false
            errorMessage = L10n.previewNoItem
            AppLogger.log("preview", "remote session no item", extra: ["url": url.absoluteString])
            return
        }
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isLoading = false
                    self.errorMessage = nil
                    AppLogger.log("preview", "remote session ready", extra: ["title": self.title])
                case .failed:
                    self.isLoading = false
                    let message = item.error?.localizedDescription ?? L10n.previewStreamFailed
                    self.errorMessage = message
                    AppLogger.log(
                        "preview",
                        "remote session failed",
                        extra: ["title": self.title, "error": message]
                    )
                case .unknown:
                    self.isLoading = true
                @unknown default:
                    break
                }
            }
        }
    }
}

struct AVPlayerContainerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

struct RemotePreviewSheet: View {
    @ObservedObject var session: RemotePreviewSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.previewRemoteTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L10n.close) {
                    dismiss()
                }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(IMovieTheme.toolbarBackground)

            Divider()

            ZStack {
                if session.errorMessage == nil {
                    AVPlayerContainerView(player: session.player)
                        .background(Color.black)
                }

                if session.isLoading, session.errorMessage == nil {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(L10n.previewLoading)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                if let error = session.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.system(size: 13))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(minWidth: 860, minHeight: 500)
        .onAppear { session.play() }
    }
}

// MARK: - Space key

struct PreviewKeyMonitor: NSViewRepresentable {
    let onPreview: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPreview: onPreview)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.start()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        private let onPreview: () -> Void
        private var monitor: Any?

        init(onPreview: @escaping () -> Void) {
            self.onPreview = onPreview
        }

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard event.keyCode == 49 else { return event }
                guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else {
                    return event
                }
                if self.isTypingContext() { return event }
                self.onPreview()
                return nil
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func isTypingContext() -> Bool {
            guard let responder = NSApp.keyWindow?.firstResponder else { return false }
            return responder is NSTextView || responder is NSSearchField
        }
    }
}
