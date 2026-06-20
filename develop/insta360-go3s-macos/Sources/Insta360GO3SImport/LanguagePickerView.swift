import SwiftUI

struct LanguagePickerView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.menuLanguage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(IMovieTheme.textSecondary)

            Picker("", selection: languageBinding) {
                ForEach(AppLanguage.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { appState.appLanguage },
            set: { appState.setLanguage($0) }
        )
    }
}
