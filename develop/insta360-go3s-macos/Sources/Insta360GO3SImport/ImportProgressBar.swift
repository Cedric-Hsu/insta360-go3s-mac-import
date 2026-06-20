import SwiftUI

struct ImportProgressBar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.importPhase {
            case .idle:
                EmptyView()
            case .running(let fileName, let written, let total):
                runningView(fileName: fileName, written: written, total: total)
            case .completed(let downloaded, let skipped):
                completedView(downloaded: downloaded, skipped: skipped)
            case .cancelled(let downloaded):
                cancelledView(downloaded: downloaded)
            case .failed(let message):
                failedView(message: message)
            }
        }
    }

    @ViewBuilder
    private func runningView(fileName: String, written: Int64, total: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.importing)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IMovieTheme.textPrimary)
                Spacer()
                Button(L10n.cancel) {
                    appState.cancelImport()
                }
                .buttonStyle(IMovieSecondaryButtonStyle())
                Text(progressLabel(written: written, total: total))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(IMovieTheme.textSecondary)
            }
            Text(fileName)
                .font(.system(size: 11))
                .foregroundStyle(IMovieTheme.textSecondary)
                .lineLimit(1)
            if let total, total > 0 {
                ProgressView(value: progressValue(written: written, total: total))
                    .tint(IMovieTheme.accentGreen)
            } else {
                ProgressView()
                    .tint(IMovieTheme.accentGreen)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(IMovieTheme.toolbarBackground)
    }

    @ViewBuilder
    private func completedView(downloaded: Int, skipped: Int) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(IMovieTheme.accentGreen)
            Text(L10n.importDoneDetail(downloaded: downloaded, skipped: skipped))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(IMovieTheme.textPrimary)
            Spacer()
            Button(L10n.revealInFinder) {
                appState.revealInFinder()
            }
            .buttonStyle(IMovieSecondaryButtonStyle())
            Button(L10n.close) {
                appState.importPhase = .idle
            }
            .buttonStyle(IMovieSecondaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(IMovieTheme.toolbarBackground)
    }

    @ViewBuilder
    private func cancelledView(downloaded: Int) -> some View {
        HStack {
            Image(systemName: "stop.circle.fill")
                .foregroundStyle(.orange)
            Text(L10n.importCancelledDetail(downloaded))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(IMovieTheme.textPrimary)
            Spacer()
            Button(L10n.close) {
                appState.importPhase = .idle
            }
            .buttonStyle(IMovieSecondaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(IMovieTheme.toolbarBackground)
    }

    @ViewBuilder
    private func failedView(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(IMovieTheme.textPrimary)
                .lineLimit(2)
            Spacer()
            Button(L10n.close) {
                appState.importPhase = .idle
            }
            .buttonStyle(IMovieSecondaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(IMovieTheme.toolbarBackground)
    }

    private func progressValue(written: Int64, total: Int64?) -> Double {
        guard let total, total > 0 else { return 0 }
        return min(1, Double(written) / Double(total))
    }

    private func progressLabel(written: Int64, total: Int64?) -> String {
        let writtenText = ByteCountFormatter.string(fromByteCount: written, countStyle: .file)
        guard let total, total > 0 else { return writtenText }
        let totalText = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        return "\(writtenText) / \(totalText)"
    }
}
