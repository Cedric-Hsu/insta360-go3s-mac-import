import SwiftUI

struct MediaBrowserView: View {
    @EnvironmentObject private var appState: AppState

    private let columns = [
        GridItem(.adaptive(minimum: IMovieTheme.cardWidth, maximum: IMovieTheme.cardWidth), spacing: 18),
    ]

    var body: some View {
        ZStack {
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
                }

                if appState.isLoadingMoreFiles {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            if let total = appState.remoteTotalCount {
                                Text(L10n.loadingMoreFiles(loaded: appState.remoteLoadedCount, total: total))
                            } else {
                                Text(L10n.loadingMoreFilesGeneric)
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(IMovieTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 16)
                    }
                }

                if let progress = appState.thumbnailLoader.remoteThumbnailProgress {
                    VStack {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(L10n.generatingRemoteThumbnails(done: progress.done, total: progress.total))
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(IMovieTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 12)
                        Spacer()
                    }
                }

                if appState.isLoading {
                    VStack {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(L10n.refreshing)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(IMovieTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 12)
                        Spacer()
                    }
                }
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
