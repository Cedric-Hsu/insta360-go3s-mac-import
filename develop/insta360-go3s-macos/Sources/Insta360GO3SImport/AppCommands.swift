import SwiftUI

struct AppSystemCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(L10n.menuAbout) {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button(L10n.settingsTitle) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .appTermination) {
            Button(L10n.quit) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }

        CommandGroup(replacing: .undoRedo) {
            Button(L10n.menuUndo) {
                NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
            }
            .keyboardShortcut("z", modifiers: .command)

            Button(L10n.menuRedo) {
                NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .pasteboard) {
            Button(L10n.menuCut) {
                NSApp.sendAction(Selector(("cut:")), to: nil, from: nil)
            }
            .keyboardShortcut("x", modifiers: .command)

            Button(L10n.menuCopy) {
                NSApp.sendAction(Selector(("copy:")), to: nil, from: nil)
            }
            .keyboardShortcut("c", modifiers: .command)

            Button(L10n.menuPaste) {
                NSApp.sendAction(Selector(("paste:")), to: nil, from: nil)
            }
            .keyboardShortcut("v", modifiers: .command)

            Button(L10n.menuSelectAllEdit) {
                NSApp.sendAction(Selector(("selectAll:")), to: nil, from: nil)
            }
            .keyboardShortcut("a", modifiers: .command)
        }

        CommandGroup(replacing: .windowSize) {
            Button(L10n.menuMinimize) {
                NSApp.keyWindow?.miniaturize(nil)
            }
            .keyboardShortcut("m", modifiers: .command)

            Button(L10n.menuZoom) {
                NSApp.keyWindow?.zoom(nil)
            }
        }

        CommandGroup(after: .windowArrangement) {
            Divider()
            Button(L10n.openMainWindow) {
                appState.openMainWindow()
            }
        }

        CommandGroup(replacing: .help) {
            Button(L10n.menuHelpItem) {
                appState.openMainWindow()
            }
        }
    }
}

struct AppFeatureCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .saveItem) {}

        CommandMenu(L10n.menuFile) {
            Button(L10n.chooseFolder) {
                appState.chooseDestinationFolder()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button(L10n.importNew) {
                appState.startImport(newOnly: true)
            }
            .keyboardShortcut("i", modifiers: .command)
            .disabled(appState.connection.ok != true || appState.isImportRunning)

            Button(L10n.importSelectedMenu) {
                appState.startImportSelected()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(!appState.canImportSelection)

            Button(L10n.cancel) {
                appState.cancelImport()
            }
            .disabled(!appState.isImportRunning)

            Divider()

            Button(L10n.revealInFinder) {
                appState.revealInFinder()
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
        }

        CommandMenu(L10n.menuView) {
            Button(L10n.sidebarCamera) { appState.selectSection(.camera) }
            Button(L10n.sidebarLibrary) { appState.selectSection(.library) }
            Divider()
            Button(L10n.checkConnection) {
                Task { await appState.runConnectionDiagnose() }
            }
            .disabled(appState.isDiagnosing)
            Button(L10n.refresh) {
                Task { await appState.refreshAll() }
            }
            .keyboardShortcut("r", modifiers: .command)
            Divider()
            Button(L10n.openPerfLog) {
                appState.openPerfLogInFinder()
            }
        }

        CommandMenu(L10n.menuSelect) {
            Button(L10n.selectAll) { appState.selectAllVisible() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            Button(L10n.deselectAll) { appState.clearSelection() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Divider()
            Button(L10n.preview) { appState.previewSelection() }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!appState.canPreviewSelection)
        }
    }
}
