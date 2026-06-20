import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(appState.connection.ok ? IMovieTheme.accentGreen : Color.red.opacity(0.85))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.connection.ok ? L10n.connected : L10n.notConnected)
                        .font(.system(size: 13, weight: .semibold))
                    Text(appState.connection.ssid ?? L10n.connectGO3SWifi(""))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if appState.pendingCount > 0 {
                Label(L10n.pendingMenuLabel(appState.pendingCount), systemImage: "arrow.down.circle")
                .font(.system(size: 12))
                .foregroundStyle(IMovieTheme.accentBlue)
            }

            if case .running(let fileName, let written, let total) = appState.importPhase {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.importing)
                        .font(.system(size: 11, weight: .semibold))
                    Text(fileName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ProgressView(value: progressValue(written: written, total: total))
                        .tint(IMovieTheme.accentGreen)
                }
            }

            Divider()

            Button {
                appState.startImport(newOnly: true)
            } label: {
                Label(L10n.importNew, systemImage: "square.and.arrow.down")
            }
            .disabled(!appState.connection.ok || appState.isImportRunning)

            if appState.isImportRunning {
                Button(role: .destructive) {
                    appState.cancelImport()
                } label: {
                    Label(L10n.cancel, systemImage: "xmark.circle")
                }
            }

            Button {
                Task {
                    await appState.runConnectionDiagnose()
                }
            } label: {
                Label(L10n.checkConnection, systemImage: "antenna.radiowaves.left.and.right")
            }
            .disabled(appState.isDiagnosing)

            Button {
                Task {
                    await appState.refreshConnection()
                    await appState.updatePendingCountFromMenu()
                }
            } label: {
                Label(L10n.refreshStatus, systemImage: "arrow.clockwise")
            }

            Button {
                appState.openMainWindow()
            } label: {
                Label(L10n.openMainWindow, systemImage: "macwindow")
            }

            Button {
                appState.revealInFinder()
            } label: {
                Label(L10n.openMediaFolder, systemImage: "folder")
            }

            Divider()

            Button(L10n.quit) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func progressValue(written: Int64, total: Int64?) -> Double {
        guard let total, total > 0 else { return 0 }
        return min(1, Double(written) / Double(total))
    }
}
