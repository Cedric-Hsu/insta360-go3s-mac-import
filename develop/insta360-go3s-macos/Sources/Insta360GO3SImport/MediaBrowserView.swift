import SwiftUI

private struct BrowserProgressOverlay: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(IMovieTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 12)
    }
}

struct MediaBrowserView: View {
    @EnvironmentObject private var appState: AppState

    private let columns = [
        GridItem(.adaptive(minimum: IMovieTheme.cardWidth, maximum: IMovieTheme.cardWidth), spacing: 18),
    ]

    private var progressOverlayMessage: String? {
        if let progress = appState.thumbnailLoader.remoteThumbnailProgress {
            return L10n.generatingRemoteThumbnails(done: progress.done, total: progress.total)
        }
        if appState.isLoadingMoreFiles {
            if let total = appState.remoteTotalCount {
                return L10n.loadingMoreFiles(loaded: appState.remoteLoadedCount, total: total)
            }
            return L10n.loadingMoreFilesGeneric
        }
        if appState.isLoading && !appState.visibleClips.isEmpty {
            return L10n.refreshing
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            if appState.visibleClips.isEmpty {
                if appState.isLoading {
                    ProgressView(L10n.loadingFileList)
                        .foregroundStyle(IMovieTheme.textSecondary)
                } else {
                    EmptyStateView()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                        ForEach(appState.visibleClips) { clip in
                            ClipCardView(clip: clip)
                        }
                    }
                    .padding(22)
                    .padding(.top, 44)
                }
            }

            if let message = progressOverlayMessage {
                BrowserProgressOverlay(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            PreviewKeyMonitor {
                guard appState.canPreviewSelection else { return }
                appState.previewSelection()
            }
        }
    }
}
