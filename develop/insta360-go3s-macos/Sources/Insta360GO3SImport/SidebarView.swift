import AppKit
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.appName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(IMovieTheme.textSecondary)
                Text(L10n.sidebarMedia)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(IMovieTheme.textPrimary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Text(L10n.sidebarBrowseHint)
                .font(.system(size: 11))
                .foregroundStyle(IMovieTheme.textSecondary.opacity(0.85))
                .padding(.horizontal, 18)
                .padding(.bottom, 12)

            ForEach(SidebarSection.allCases) { section in
                SidebarRow(
                    title: section.title,
                    icon: section.icon,
                    badge: badge(for: section),
                    isSelected: appState.selectedSection == section
                ) {
                    appState.selectSection(section)
                }
            }

            Spacer()

            ConnectionBadge(connection: appState.connection) {
                if appState.connection.ok {
                    Task { await appState.refreshAll() }
                } else {
                    Task { await appState.runConnectionDiagnose() }
                }
            }
            .padding(16)
        }
        .frame(minWidth: IMovieTheme.sidebarWidth)
        .background(IMovieTheme.sidebarBackground)
    }

    private func badge(for section: SidebarSection) -> Int? {
        switch section {
        case .camera where appState.pendingCount > 0:
            return appState.pendingCount
        default:
            return nil
        }
    }
}

private struct SidebarRow: View {
    let title: String
    let icon: String
    let badge: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                if let badge {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(IMovieTheme.accentBlue.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? IMovieTheme.textPrimary : IMovieTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? IMovieTheme.sidebarSelection : Color.clear)
            )
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }
}

private struct ConnectionBadge: View {
    let connection: ConnectionInfo
    let onDiagnose: () -> Void

    var body: some View {
        Button(action: onDiagnose) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.statusTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(IMovieTheme.textPrimary)
                    Text(connection.ssid ?? L10n.defaultWifiSSID)
                        .font(.system(size: 11))
                        .foregroundStyle(IMovieTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "stethoscope")
                    .font(.system(size: 12))
                    .foregroundStyle(IMovieTheme.textSecondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        }
        .buttonStyle(.plain)
        .help(L10n.refreshConnectionHelp(connected: connection.ok))
    }

    private var statusDotColor: Color {
        switch connection.statusColor {
        case .connected:
            return IMovieTheme.accentGreen
        case .wifiOnly:
            return Color.orange
        case .disconnected:
            return Color.red.opacity(0.8)
        }
    }
}
