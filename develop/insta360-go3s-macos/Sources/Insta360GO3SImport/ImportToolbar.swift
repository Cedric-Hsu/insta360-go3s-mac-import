import AppKit
import SwiftUI

struct ImportToolbar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.selectedSection.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(IMovieTheme.textPrimary)
                Text(toolbarStatusLine)
                    .font(.system(size: 12))
                    .foregroundStyle(IMovieTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if appState.selectedSection == .camera && appState.connection.ok {
                Picker(L10n.filterLabel, selection: cameraFilterBinding) {
                    ForEach(CameraImportFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 300)
            }

            if !appState.selectedClipIDs.isEmpty {
                Text(L10n.selectedCount(appState.selectedClipIDs.count))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(IMovieTheme.textSecondary)
            }

            Button {
                appState.chooseDestinationFolder()
            } label: {
                Label(appState.destinationURL.lastPathComponent, systemImage: "folder")
            }
            .buttonStyle(IMovieSecondaryButtonStyle())

            Button {
                Task { await appState.refreshAll() }
            } label: {
                Label(L10n.refresh, systemImage: "arrow.clockwise")
            }
            .buttonStyle(IMovieSecondaryButtonStyle())
            .disabled(appState.isLoading || appState.isImportRunning)

            if !appState.connection.ok {
                Button {
                    Task { await appState.runConnectionDiagnose() }
                } label: {
                    Label(L10n.checkConnection, systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(IMovieSecondaryButtonStyle())
                .disabled(appState.isDiagnosing || appState.isImportRunning)
            }

            if appState.canImportSelection {
                Button {
                    appState.startImportSelected()
                } label: {
                    Label(L10n.importSelected, systemImage: "checkmark.circle")
                }
                .buttonStyle(IMoviePrimaryButtonStyle())
            }

            if appState.connection.ok && !appState.isImportRunning {
                Button {
                    appState.startImport(newOnly: true)
                } label: {
                    Label(L10n.importNew, systemImage: "square.and.arrow.down")
                }
                .buttonStyle(IMoviePrimaryButtonStyle())
            } else {
                Button {
                    appState.startImport(newOnly: true)
                } label: {
                    Label(L10n.importNew, systemImage: "square.and.arrow.down")
                }
                .buttonStyle(IMovieSecondaryButtonStyle())
                .disabled(true)
            }

            if appState.isImportRunning {
                Button(L10n.cancel) {
                    appState.cancelImport()
                }
                .buttonStyle(IMovieSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(IMovieTheme.toolbarBackground)
    }

    private var cameraFilterBinding: Binding<CameraImportFilter> {
        Binding(
            get: { appState.cameraImportFilter },
            set: { appState.setCameraFilter($0) }
        )
    }

    private var toolbarStatusLine: String {
        if appState.isDiagnosing && !appState.connection.ok {
            return L10n.diagnosing
        }
        if let progress = appState.thumbnailLoader.remoteThumbnailProgress {
            return L10n.generatingRemoteThumbnails(done: progress.done, total: progress.total)
        }
        if appState.isLoadingMoreFiles, let total = appState.remoteTotalCount {
            return L10n.loadingMoreFiles(loaded: appState.remoteLoadedCount, total: total)
        }
        if appState.isLoading && appState.visibleClips.isEmpty && !appState.hasCameraClips {
            return L10n.loadingFileList
        }
        if appState.isLoading && !appState.visibleClips.isEmpty {
            return L10n.refreshingList
        }

        switch appState.selectedSection {
        case .camera:
            if !appState.connection.ok {
                return L10n.notConnectedHint
            }
            if appState.clips.isEmpty {
                return L10n.connectedNoVideos
            }
            return appState.connectionSubtitle(for: .camera)
        case .library:
            if appState.clips.isEmpty {
                return L10n.libraryEmpty
            }
            return L10n.librarySummary(appState.clips.count)
        }
    }
}

struct IMoviePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(IMovieTheme.accentGreen.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundStyle(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct IMovieSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(nsColor: .controlBackgroundColor)
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
            .foregroundStyle(IMovieTheme.textPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(IMovieTheme.divider, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
