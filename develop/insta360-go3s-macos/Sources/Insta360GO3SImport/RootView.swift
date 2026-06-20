import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                ImportToolbar()
                Divider().overlay(IMovieTheme.divider)
                MediaBrowserView()
                ImportProgressBar()
            }
            .background(IMovieTheme.browserBackground)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IMovieTheme.windowBackground)
        .sheet(item: $appState.remotePreviewSession, onDismiss: {
            appState.finishRemotePreviewDismissal()
        }) { session in
            RemotePreviewSheet(session: session)
        }
    }
}
