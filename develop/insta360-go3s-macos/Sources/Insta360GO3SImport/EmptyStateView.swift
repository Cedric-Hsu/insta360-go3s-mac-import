import SwiftUI

struct DiagnoseStepItem: Identifiable {
    let id = UUID()
    let ok: Bool
    let message: String
}

struct ConnectionDiagnoseResult {
    let ok: Bool
    let hint: String
    let steps: [DiagnoseStepItem]

    static func from(json: [String: Any]) -> ConnectionDiagnoseResult {
        let steps = (json["steps"] as? [[String: Any]] ?? []).map { item in
            DiagnoseStepItem(
                ok: item["ok"] as? Bool ?? false,
                message: item["message"] as? String ?? L10n.unknownCheckItem
            )
        }
        return ConnectionDiagnoseResult(
            ok: json["ok"] as? Bool ?? false,
            hint: json["hint"] as? String ?? "",
            steps: steps
        )
    }
}

enum SetupGuide {
    static var quickTransferSteps: [String] {
        [
            L10n.setupStepPodPower,
            L10n.setupStepPhoneApp,
            L10n.setupStepMacWifi,
            L10n.setupStepQuickTransfer,
            L10n.setupStepCheckConnection,
        ]
    }

    static var appRequirementCallout: String { L10n.setupAppRequirementCallout }
    static var sessionNote: String { L10n.setupSessionNote }
}

struct EmptyStateView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                header
                contentCard
                diagnosePanel
                actionButtons
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 32)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(IMovieTheme.browserBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: scenario.icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(scenario.iconColor)
            Text(scenario.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(IMovieTheme.textPrimary)
            Text(scenario.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(IMovieTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if scenario.showsConnectionStatus {
                connectionStatusRow
            }

            if scenario.showsAppRequirement {
                appRequirementCallout
            }

            if !scenario.steps.isEmpty {
                Text(scenario.stepsHeading)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IMovieTheme.textSecondary)

                ForEach(Array(scenario.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(IMovieTheme.accentBlue.opacity(0.85)))
                        Text(step)
                            .font(.system(size: 13))
                            .foregroundStyle(IMovieTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let note = scenario.note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(IMovieTheme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(IMovieTheme.divider.opacity(0.5), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var diagnosePanel: some View {
        if scenario.showDiagnose {
            if appState.isDiagnosing {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(L10n.emptyDiagnosing)
                        .font(.system(size: 12))
                        .foregroundStyle(IMovieTheme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            } else if let result = appState.diagnoseResult {
                DiagnoseInlineResults(result: result)
            }
        } else if appState.isLoading && scenario.showRefresh {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(L10n.loadingFileList)
                    .font(.system(size: 12))
                    .foregroundStyle(IMovieTheme.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    private var connectionStatusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appState.connection.ok ? IMovieTheme.accentGreen : Color.orange)
                .frame(width: 8, height: 8)
            Text(appState.connection.ok ? L10n.emptyCameraReachable : L10n.emptyCameraNotReachable)
                .font(.system(size: 12, weight: .semibold))
            if let ssid = appState.connection.ssid, !ssid.isEmpty {
                Text("·")
                    .foregroundStyle(IMovieTheme.textSecondary)
                Text(ssid)
                    .font(.system(size: 11))
                    .foregroundStyle(IMovieTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(IMovieTheme.sidebarSelection))
    }

    private var appRequirementCallout: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.orange)
                .padding(.top, 1)
            Text(SetupGuide.appRequirementCallout)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(IMovieTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 10) {
            if scenario.showDiagnose {
                Button {
                    Task { await appState.runConnectionDiagnose() }
                } label: {
                    Label(L10n.checkConnection, systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(IMoviePrimaryButtonStyle())
                .disabled(appState.isDiagnosing || appState.isImportRunning)
            }

            if scenario.showRefresh {
                Button {
                    Task { await appState.refreshAll() }
                } label: {
                    Label(L10n.emptyRefreshList, systemImage: "arrow.clockwise")
                }
                .buttonStyle(IMoviePrimaryButtonStyle())
                .disabled(appState.isLoading || appState.isImportRunning)
            }

            if scenario.showWiFiSettings {
                Button {
                    appState.openWiFiSettings()
                } label: {
                    Label(L10n.emptyWifiSettings, systemImage: "wifi")
                }
                .buttonStyle(IMovieSecondaryButtonStyle())
            }

            if scenario.showChooseFolder {
                Button {
                    appState.chooseDestinationFolder()
                } label: {
                    Label(L10n.emptyChooseMediaFolder, systemImage: "folder")
                }
                .buttonStyle(IMovieSecondaryButtonStyle())
            }
        }
    }

    private var scenario: EmptyScenario {
        EmptyScenario.resolve(
            section: appState.selectedSection,
            connectionOK: appState.connection.ok,
            cameraFilter: appState.cameraImportFilter,
            hasCameraClips: appState.hasCameraClips
        )
    }
}

struct DiagnoseInlineResults: View {
    let result: ConnectionDiagnoseResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.diagnoseResultsTitle)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(result.ok ? L10n.diagnosePassed : L10n.diagnoseFailed)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((result.ok ? IMovieTheme.accentGreen : Color.orange).opacity(0.15))
                    .foregroundStyle(result.ok ? IMovieTheme.accentGreen : .orange)
                    .clipShape(Capsule())
            }

            if !result.hint.isEmpty {
                Text(result.hint)
                    .font(.system(size: 12))
                    .foregroundStyle(IMovieTheme.textPrimary)
            }

            ForEach(result.steps.prefix(6)) { step in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: step.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(step.ok ? IMovieTheme.accentGreen : .orange)
                    Text(step.message)
                        .font(.system(size: 11))
                        .foregroundStyle(IMovieTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if result.steps.count > 6 {
                Text(L10n.diagnoseMoreSteps(result.steps.count - 6))
                    .font(.system(size: 10))
                    .foregroundStyle(IMovieTheme.textSecondary.opacity(0.8))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke((result.ok ? IMovieTheme.accentGreen : Color.orange).opacity(0.35), lineWidth: 1)
        )
    }
}

private struct EmptyScenario {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let stepsHeading: String
    let steps: [String]
    let note: String?
    let showsConnectionStatus: Bool
    let showsAppRequirement: Bool
    let showDiagnose: Bool
    let showRefresh: Bool
    let showWiFiSettings: Bool
    let showChooseFolder: Bool

    static func resolve(
        section: SidebarSection,
        connectionOK: Bool,
        cameraFilter: CameraImportFilter,
        hasCameraClips: Bool
    ) -> EmptyScenario {
        switch section {
        case .camera:
            if !connectionOK {
                return EmptyScenario(
                    title: L10n.emptyNotConnectedTitle,
                    subtitle: L10n.emptyNotConnectedSubtitle,
                    icon: "wifi.exclamationmark",
                    iconColor: .orange,
                    stepsHeading: L10n.emptyConnectionStepsHeading,
                    steps: SetupGuide.quickTransferSteps,
                    note: SetupGuide.sessionNote,
                    showsConnectionStatus: true,
                    showsAppRequirement: true,
                    showDiagnose: true,
                    showRefresh: false,
                    showWiFiSettings: true,
                    showChooseFolder: false
                )
            }
            if hasCameraClips {
                switch cameraFilter {
                case .imported:
                    return EmptyScenario(
                        title: L10n.filterEmptyImportedTitle,
                        subtitle: L10n.filterEmptyImportedSubtitle,
                        icon: "checkmark.circle",
                        iconColor: IMovieTheme.accentGreen,
                        stepsHeading: L10n.emptyNextStepsHeading,
                        steps: [
                            L10n.emptyNextLibrary,
                            L10n.emptyFilterTryAll,
                        ],
                        note: nil,
                        showsConnectionStatus: true,
                        showsAppRequirement: false,
                        showDiagnose: false,
                        showRefresh: true,
                        showWiFiSettings: false,
                        showChooseFolder: false
                    )
                case .notImported:
                    return EmptyScenario(
                        title: L10n.filterEmptyNotImportedTitle,
                        subtitle: L10n.filterEmptyNotImportedSubtitle,
                        icon: "checkmark.circle",
                        iconColor: IMovieTheme.accentGreen,
                        stepsHeading: L10n.emptyNextStepsHeading,
                        steps: [
                            L10n.emptyNextLibrary,
                            L10n.emptyFilterTryAll,
                        ],
                        note: nil,
                        showsConnectionStatus: true,
                        showsAppRequirement: false,
                        showDiagnose: false,
                        showRefresh: true,
                        showWiFiSettings: false,
                        showChooseFolder: false
                    )
                case .all:
                    break
                }
            }
            return EmptyScenario(
                title: L10n.emptyNoVideosTitle,
                subtitle: L10n.emptyNoVideosSubtitle,
                icon: "video.slash",
                iconColor: IMovieTheme.textSecondary,
                stepsHeading: L10n.emptyTroubleshootHeading,
                steps: [
                    L10n.emptyTroubleshootAppConnected,
                    L10n.emptyTroubleshootQFT,
                    L10n.emptyTroubleshootRecord,
                    L10n.emptyTroubleshootRefresh,
                ],
                note: nil,
                showsConnectionStatus: true,
                showsAppRequirement: false,
                showDiagnose: false,
                showRefresh: true,
                showWiFiSettings: false,
                showChooseFolder: false
            )

        case .library:
            return EmptyScenario(
                title: L10n.emptyLibraryTitle,
                subtitle: L10n.emptyLibrarySubtitle,
                icon: "folder",
                iconColor: IMovieTheme.textSecondary,
                stepsHeading: L10n.emptyImportMethodsHeading,
                steps: [
                    L10n.emptyImportWireless,
                    L10n.emptyImportChooseFolder,
                ],
                note: L10n.emptyDefaultFolderNote,
                showsConnectionStatus: false,
                showsAppRequirement: false,
                showDiagnose: false,
                showRefresh: false,
                showWiFiSettings: false,
                showChooseFolder: true
            )
        }
    }
}
