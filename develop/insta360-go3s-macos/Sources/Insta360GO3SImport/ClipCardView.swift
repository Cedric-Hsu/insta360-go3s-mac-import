import SwiftUI

struct ClipCardView: View {
    @EnvironmentObject private var appState: AppState
    let clip: ClipItem
    @State private var isHovered = false

    private let cardShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    private var isSelected: Bool {
        appState.selectedClipIDs.contains(clip.selectionKey)
    }

    private var thumbnail: VideoThumbnail? {
        appState.thumbnailLoader.thumbnail(for: clip, destination: appState.destinationURL)
    }

    private var borderColor: Color {
        if isSelected { return Color.accentColor }
        if showsImportedState { return IMovieTheme.importedBorder }
        if showsPendingState { return IMovieTheme.pendingBorder }
        return IMovieTheme.cardBorder
    }

    private var borderLineWidth: CGFloat {
        if isSelected || showsImportedState || showsPendingState { return 2 }
        return 1
    }

    /// 仅在「相机」页对已导入项展示绿框；「待导入」页展示橙框；「媒体库」不用导入色。
    private var showsImportedState: Bool {
        appState.selectedSection == .camera && clip.isImported
    }

    private var showsPendingState: Bool {
        appState.selectedSection == .camera && !clip.isImported && clip.remotePath != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnailSection

            Text(clip.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(IMovieTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(clip.displayDate)
                .font(.system(size: 11))
                .foregroundStyle(IMovieTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            if let size = clip.displaySize {
                Text(size)
                    .font(.system(size: 10))
                    .foregroundStyle(IMovieTheme.textSecondary.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(width: IMovieTheme.cardWidth, alignment: .topLeading)
        .background(cardShape.fill(cardBackground))
        .overlay(cardShape.strokeBorder(borderColor, lineWidth: borderLineWidth))
        .clipShape(cardShape)
        .compositingGroup()
        .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0.06), radius: 3, y: 1)
        .onHover { hovering in
            isHovered = hovering
        }
        .gesture(
            TapGesture(count: 2)
                .onEnded { appState.preview(clip: clip) }
                .exclusively(before: TapGesture(count: 1).onEnded {
                    appState.toggleSelection(for: clip)
                })
        )
        .onAppear {
            appState.thumbnailLoader.load(for: clip, destination: appState.destinationURL)
        }
    }

    private var thumbnailSection: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .bottomLeading) {
                ZStack(alignment: .bottomTrailing) {
                    thumbnailView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    statusBadge
                        .padding(6)
                }

                if let duration = appState.thumbnailLoader.duration(for: clip) {
                    Text(L10n.formatDuration(duration))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.68))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .padding(6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .clipShape(RoundedRectangle(cornerRadius: IMovieTheme.cardCornerRadius, style: .continuous))

            if isSelected || isHovered {
                Button {
                    appState.toggleSelection(for: clip)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(isSelected ? Color.accentColor : .white, Color.black.opacity(0.35))
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
                .padding(6)
            }
        }
    }

    private var cardBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.08)
        }
        if showsImportedState {
            return IMovieTheme.accentGreen.opacity(0.06)
        }
        if showsPendingState {
            return Color.orange.opacity(0.05)
        }
        return isHovered ? IMovieTheme.cardHover : IMovieTheme.cardBackground
    }

    @ViewBuilder
    private var statusBadge: some View {
        if showsImportedState {
            StatusPill(text: L10n.imported, color: IMovieTheme.accentGreen, filled: true)
        } else if showsPendingState {
            StatusPill(text: L10n.pendingImport, color: .orange, filled: false)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            CrispThumbnailImage(thumbnail: thumbnail)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay {
                    if isHovered {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 36))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.black.opacity(0.35))
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    }
                }
        } else {
            RoundedRectangle(cornerRadius: IMovieTheme.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            IMovieTheme.placeholderTop,
                            IMovieTheme.placeholderBottom,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    if isHovered {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 36))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.black.opacity(0.35))
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    }
                }
        }
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color
    let filled: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(filled ? color : color.opacity(0.15))
            .foregroundStyle(filled ? Color.white : color)
            .clipShape(Capsule())
    }
}
