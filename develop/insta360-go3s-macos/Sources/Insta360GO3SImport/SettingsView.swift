import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                Picker(L10n.menuLanguage, selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text(L10n.settingsGeneral)
            }

            Section {
                LabeledContent(L10n.settingsImportFolder, value: appState.destinationURL.path)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(2)
                Button(L10n.chooseFolder) {
                    appState.chooseDestinationFolder()
                }
            } header: {
                Text(L10n.settingsStorage)
            }

            Section {
                Button(L10n.openPerfLog) {
                    appState.openPerfLogInFinder()
                }
            } header: {
                Text(L10n.settingsAdvanced)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 480)
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { appState.appLanguage },
            set: { appState.setLanguage($0) }
        )
    }
}
