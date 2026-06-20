import SwiftUI

@main
struct Insta360GO3SImportApp: App {
    @NSApplicationDelegateAdaptor(PreviewAppDelegate.self) private var previewAppDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .id(appState.appLanguage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(IMovieTheme.windowBackground)
                .preferredColorScheme(.light)
                .configureMainWindow(minWidth: 1120, minHeight: 700)
        }
        .defaultSize(width: 1120, height: 700)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            AppSystemCommands(appState: appState)
            AppFeatureCommands(appState: appState)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .id(appState.appLanguage)
        }

        MenuBarExtra(L10n.menuBarTitle, systemImage: "video.circle.fill") {
            MenuBarView()
                .environmentObject(appState)
                .id(appState.appLanguage)
                .preferredColorScheme(.light)
        }
        .menuBarExtraStyle(.window)
    }
}
