import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedSection: SidebarSection = .camera
    @Published var clips: [ClipItem] = []
    @Published var connection = ConnectionInfo()
    @Published var importPhase: ImportPhase = .idle
    @Published var destinationURL: URL
    @Published var isLoading = false
    @Published var statusMessage = L10n.initialStatus
    @Published var pendingCount = 0
    @Published var selectedClipIDs: Set<String> = []
    @Published var remotePreviewSession: RemotePreviewSession?
    @Published var diagnoseResult: ConnectionDiagnoseResult?
    @Published var isDiagnosing = false
    @Published private(set) var currentImportDownloaded = 0
    @Published var isLoadingMoreFiles = false
    @Published var remoteTotalCount: Int?
    @Published var remoteLoadedCount = 0
    @Published var appLanguage: AppLanguage = AppLanguage.load()
    @Published var cameraImportFilter: CameraImportFilter = .all

    let thumbnailLoader = ThumbnailLoader()

    private var bridge: PythonBridge?
    private var importTask: Task<Void, Never>?
    private var sectionLoadTask: Task<Void, Never>?
    private var sectionReloadDebounceTask: Task<Void, Never>?
    private var cameraSummaryTask: Task<[String: Any], Error>?
    private var loadMoreTask: Task<Void, Never>?
    private var cachedCameraSummary: [String: Any]?
    private var cachedCameraSummaryDest: String?
    private var cachedCameraSummaryAt: Date?
    private let summaryCacheTTL: TimeInterval = 45
    private let sectionReloadDebounceNs: UInt64 = 300_000_000
    private var loadGeneration = 0
    private var lastFocusedClipKey: String?
    private var thumbnailCancellable: AnyCancellable?
    private let sleepGuard = SystemSleepGuard()

    var isImportRunning: Bool {
        if case .running = importPhase { return true }
        return false
    }

    var canImportSelection: Bool {
        connection.ok && !isImportRunning && !importableSelectedRemotePaths.isEmpty
    }

    var importableSelectedRemotePaths: [String] {
        clips
            .filter { selectedClipIDs.contains($0.selectionKey) && !$0.isImported }
            .compactMap(\.remotePath)
    }

    var canPreviewSelection: Bool {
        previewTargetClip() != nil
    }

    var visibleClips: [ClipItem] {
        guard selectedSection == .camera else { return clips }
        switch cameraImportFilter {
        case .all:
            return clips
        case .imported:
            return clips.filter(\.isImported)
        case .notImported:
            return clips.filter { !$0.isImported }
        }
    }

    var hasCameraClips: Bool {
        selectedSection == .camera && !clips.isEmpty
    }

    init() {
        let movies = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/GO3S", isDirectory: true)
        destinationURL = movies
        try? FileManager.default.createDirectory(at: movies, withIntermediateDirectories: true)
        L10n.language = appLanguage
        ClipItem.refreshDateFormatterLocale()
        statusMessage = L10n.initialStatus
        thumbnailCancellable = thumbnailLoader.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        Task { await bootstrap() }
    }

    func bootstrap() async {
        AppLogger.log("app_state", "bootstrap start")
        do {
            bridge = try PythonBridge()
            bridge?.uiLanguageCode = appLanguage.apiLanguageCode()
            await refreshAll()
            AppLogger.log("app_state", "bootstrap done")
        } catch {
            AppLogger.log("app_state", "bootstrap error", extra: ["error": error.localizedDescription])
            statusMessage = error.localizedDescription
        }
    }

    func refreshAll() async {
        invalidateSummaryCache()
        await AppLogger.timed("app_state", "refreshAll") {
            await refreshConnection()
            if !connection.ok {
                pendingCount = 0
            }
            await reloadCurrentSection(forceRefresh: true)
        }
    }

    func refreshConnection() async {
        guard let bridge else { return }

        do {
            let json = try await AppLogger.timed("app_state", "refreshConnection") {
                try await bridge.runJSON(arguments: [
                    "-m", "insta360_go3s_wifi.cli", "ui", "connection",
                ])
            }
            connection = ConnectionInfo(
                ok: json["ok"] as? Bool ?? false,
                ssid: json["ssid"] as? String,
                pingMessage: json["ping_message"] as? String ?? "",
                looksLikeGo3s: json["looks_like_go3s"] as? Bool ?? false,
                wifiOnly: json["wifi_only"] as? Bool ?? false
            )
            if connection.ok {
                statusMessage = connectionSubtitle(for: selectedSection)
            } else {
                statusMessage = L10n.notConnectedCamera
            }
        } catch {
            connection = ConnectionInfo(ok: false)
            statusMessage = error.localizedDescription
        }
    }

    func reloadCurrentSection(forceRefresh: Bool = false) async {
        sectionLoadTask?.cancel()
        bridge?.cancelJSON()
        let task = Task {
            await performReloadCurrentSection(forceRefresh: forceRefresh)
        }
        sectionLoadTask = task
        await task.value
    }

    private func performReloadCurrentSection(forceRefresh: Bool = false) async {
        await AppLogger.timed("app_state", "reloadSection", extra: ["section": selectedSection.rawValue]) {
            selectedClipIDs.removeAll()
            switch selectedSection {
            case .camera:
                await loadCameraClips(forceRefresh: forceRefresh)
            case .library:
                await loadLocalLibrary()
            }
        }
    }

    private func loadCameraClips(forceRefresh: Bool = false) async {
        guard let bridge, connection.ok else {
            clips = []
            if !connection.ok {
                statusMessage = L10n.notConnectedCamera
            }
            AppLogger.log("app_state", "loadCameraClips skipped", extra: ["reason": "not_connected"])
            return
        }
        let generation = beginLoading()
        defer { endLoading(generation) }

        do {
            let json = try await AppLogger.timed("app_state", "fetchCameraSummary", extra: ["section": "camera"]) {
                try await fetchCameraSummary(bridge: bridge, forceRefresh: forceRefresh)
            }
            guard isCurrentLoad(generation) else {
                AppLogger.log("app_state", "loadCameraClips stale", extra: ["generation": generation])
                return
            }
            let applyStarted = ContinuousClock.now
            applySummary(json)
            updateRemoteProgress(from: json)
            AppLogger.log(
                "app_state",
                "applySummary done",
                durationMs: elapsedMs(since: applyStarted),
                extra: ["clips": clips.count, "section": "camera"]
            )
            if json["has_more"] as? Bool == true {
                scheduleLoadMoreFiles(seed: json)
            }
        } catch {
            guard isCurrentLoad(generation) else { return }
            if error is CancellationError {
                AppLogger.log("app_state", "loadCameraClips cancelled")
                return
            }
            clips = []
            statusMessage = error.localizedDescription
            await refreshConnection()
        }
    }

    private func loadLocalLibrary() async {
        guard let bridge else { return }
        let generation = beginLoading()
        defer { endLoading(generation) }

        do {
            let json = try await AppLogger.timed("app_state", "loadLocalLibrary") {
                try await bridge.runJSON(arguments: [
                    "-m", "insta360_go3s_wifi.cli", "ui", "library",
                    destinationURL.path,
                ])
            }
            guard isCurrentLoad(generation) else { return }
            let files = json["files"] as? [String] ?? []
            clips = files
                .filter { $0.lowercased().hasSuffix(".mp4") }
                .map { ClipItem.fromLocal($0) }
            statusMessage = connectionSubtitle(for: .library)
        } catch {
            guard isCurrentLoad(generation) else { return }
            clips = []
            statusMessage = error.localizedDescription
        }
    }

    func setCameraFilter(_ filter: CameraImportFilter) {
        guard cameraImportFilter != filter else { return }
        cameraImportFilter = filter
        selectedClipIDs.removeAll()
        statusMessage = connectionSubtitle(for: selectedSection)
    }

    func selectSection(_ section: SidebarSection) {
        selectedSection = section
        clips = []
        selectedClipIDs.removeAll()
        if connection.ok {
            statusMessage = connectionSubtitle(for: section)
        }
        scheduleSectionReload()
    }

    private func scheduleSectionReload() {
        sectionReloadDebounceTask?.cancel()
        sectionReloadDebounceTask = Task {
            try? await Task.sleep(nanoseconds: sectionReloadDebounceNs)
            guard !Task.isCancelled else { return }
            await reloadCurrentSection()
        }
    }

    private func invalidateSummaryCache() {
        cachedCameraSummary = nil
        cachedCameraSummaryDest = nil
        cachedCameraSummaryAt = nil
        cameraSummaryTask?.cancel()
        cameraSummaryTask = nil
        loadMoreTask?.cancel()
        loadMoreTask = nil
        isLoadingMoreFiles = false
        remoteTotalCount = nil
        remoteLoadedCount = 0
    }

    func toggleSelection(for clip: ClipItem) {
        let key = clip.selectionKey
        lastFocusedClipKey = key
        if selectedClipIDs.contains(key) {
            selectedClipIDs.remove(key)
        } else {
            selectedClipIDs.insert(key)
        }
    }

    func preview(clip: ClipItem) {
        lastFocusedClipKey = clip.selectionKey
        AppLogger.log("preview", "request", extra: ["name": clip.name, "remote": clip.remotePath ?? ""])

        if let localURL = clip.localPreviewURL(destination: destinationURL) {
            remotePreviewSession = nil
            AppLogger.log("preview", "quicklook local", extra: ["path": localURL.path])
            PreviewAppDelegate.showQuickLook(for: localURL)
            return
        }

        if let remoteURL = clip.remotePreviewURL() {
            guard connection.ok else {
                statusMessage = L10n.previewNeedsConnection
                return
            }
            AppLogger.log("preview", "remote sheet", extra: ["url": remoteURL.absoluteString])
            remotePreviewSession = RemotePreviewSession(url: remoteURL, title: clip.name)
            return
        }

        statusMessage = L10n.previewUnavailable
    }

    func previewSelection() {
        guard remotePreviewSession == nil else { return }
        guard let clip = previewTargetClip() else {
            statusMessage = L10n.selectClipToPreview
            return
        }
        preview(clip: clip)
    }

    func dismissRemotePreview() {
        remotePreviewSession = nil
    }

    func finishRemotePreviewDismissal() {
        remotePreviewSession?.cleanup()
        remotePreviewSession = nil
    }

    private func previewTargetClip() -> ClipItem? {
        if selectedClipIDs.count == 1,
           let key = selectedClipIDs.first,
           let clip = clips.first(where: { $0.selectionKey == key }) {
            return clip
        }
        if let key = lastFocusedClipKey,
           let clip = clips.first(where: { $0.selectionKey == key }) {
            return clip
        }
        if let key = selectedClipIDs.first,
           let clip = clips.first(where: { $0.selectionKey == key }) {
            return clip
        }
        return nil
    }

    func selectAllVisible() {
        selectedClipIDs = Set(visibleClips.map(\.selectionKey))
    }

    func clearSelection() {
        selectedClipIDs.removeAll()
    }

    func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationURL
        panel.message = L10n.chooseImportFolder
        if panel.runModal() == .OK, let url = panel.url {
            destinationURL = url
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            Task { await reloadCurrentSection() }
        }
    }

    func updatePendingCountFromMenu() async {
        await updatePendingCount()
    }

    func startImport(newOnly: Bool = true) {
        startImport(remotePaths: nil, newOnly: newOnly)
    }

    func startImportSelected() {
        let paths = importableSelectedRemotePaths
        guard !paths.isEmpty else {
            statusMessage = L10n.selectUnimportedFirst
            return
        }
        startImport(remotePaths: paths, newOnly: true)
    }

    func cancelImport() {
        bridge?.cancelImport()
        importTask?.cancel()
        if isImportRunning {
            importPhase = .running(fileName: L10n.cancelling, written: 0, total: nil)
        }
    }

    func revealInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: destinationURL.path)
    }

    func openPerfLogInFinder() {
        AppLogger.revealInFinder()
    }

    func setLanguage(_ language: AppLanguage) {
        guard appLanguage != language else { return }
        appLanguage = language
        language.save()
        L10n.language = language
        ClipItem.refreshDateFormatterLocale()
        bridge?.uiLanguageCode = language.apiLanguageCode()
        statusMessage = connectionSubtitle(for: selectedSection)
        AppLogger.log("app_state", "language changed", extra: ["language": language.rawValue])
    }

    func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func openWiFiSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.network?Wi-Fi",
            "x-apple.systempreferences:com.apple.Network-Settings.extension",
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func runConnectionDiagnose() async {
        guard let bridge else {
            statusMessage = L10n.cliNotReady
            diagnoseResult = ConnectionDiagnoseResult(
                ok: false,
                hint: L10n.cliNotReady,
                steps: []
            )
            return
        }

        if connection.ok {
            isDiagnosing = true
            diagnoseResult = nil
            await refreshConnection()
            await reloadCurrentSection()
            diagnoseResult = ConnectionDiagnoseResult(
                ok: true,
                hint: L10n.diagnoseConnectedHint,
                steps: [
                    DiagnoseStepItem(ok: true, message: L10n.diagnoseStepConnectionOk),
                    DiagnoseStepItem(ok: true, message: L10n.diagnoseStepListReloaded),
                ]
            )
            statusMessage = connectionSubtitle(for: selectedSection)
            isDiagnosing = false
            return
        }

        isDiagnosing = true
        diagnoseResult = nil

        do {
            let json = try await bridge.runJSON(arguments: [
                "-m", "insta360_go3s_wifi.cli", "ui", "diagnose",
            ])
            diagnoseResult = ConnectionDiagnoseResult.from(json: json)
            await refreshConnection()
            if connection.ok {
                if selectedSection != .library {
                    await reloadCurrentSection()
                }
            }
            if let hint = diagnoseResult?.hint, !hint.isEmpty, !connection.ok {
                statusMessage = hint
            } else if connection.ok {
                statusMessage = connectionSubtitle(for: selectedSection)
            }
        } catch {
            diagnoseResult = ConnectionDiagnoseResult(
                ok: false,
                hint: error.localizedDescription,
                steps: []
            )
            statusMessage = error.localizedDescription
        }
        isDiagnosing = false
    }

    private func startImport(remotePaths: [String]?, newOnly: Bool) {
        guard let bridge else { return }
        guard connection.ok else {
            importPhase = .failed(message: L10n.importNeedsPairing)
            return
        }
        guard !isImportRunning else { return }

        let pathsFile: URL?
        if let remotePaths {
            guard let file = writePathsFile(remotePaths) else { return }
            pathsFile = file
        } else {
            pathsFile = nil
        }

        currentImportDownloaded = 0
        importPhase = .running(fileName: L10n.preparing, written: 0, total: nil)
        importTask?.cancel()

        importTask = Task {
            sleepGuard.begin(reason: "GO 3S WiFi import")
            defer { sleepGuard.end() }
            do {
                try await bridge.runImportStreaming(
                    dest: destinationURL,
                    newOnly: newOnly,
                    pathsFile: pathsFile
                ) { event in
                    Task { @MainActor in
                        self.handleImportEvent(event)
                    }
                }
            } catch is CancellationError {
                importPhase = .cancelled(downloaded: currentImportDownloaded)
                statusMessage = L10n.importCancelledShort
                await reloadCurrentSection()
            } catch PythonBridgeError.importCancelled {
                importPhase = .cancelled(downloaded: currentImportDownloaded)
                statusMessage = L10n.importCancelled(currentImportDownloaded)
                await reloadCurrentSection()
            } catch {
                if Task.isCancelled {
                    importPhase = .cancelled(downloaded: currentImportDownloaded)
                    await reloadCurrentSection()
                } else {
                    importPhase = .failed(message: error.localizedDescription)
                    await reloadCurrentSection()
                }
            }
            if let pathsFile {
                try? FileManager.default.removeItem(at: pathsFile)
            }
        }
    }

    private func writePathsFile(_ paths: [String]) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("insta360-import-\(UUID().uuidString).txt")
        let body = paths.joined(separator: "\n")
        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            importPhase = .failed(message: L10n.writeImportListFailed(error.localizedDescription))
            return nil
        }
    }

    private func handleImportEvent(_ event: ImportStreamEvent) {
        switch event.type {
        case "import_begin":
            let pending = event.payload["pending_files"] as? Int ?? 0
            pendingCount = pending
        case "file_start":
            let name = event.fileName ?? L10n.downloading
            importPhase = .running(fileName: name, written: 0, total: nil)
        case "file_progress":
            let name: String
            if case .running(let current, _, _) = importPhase {
                name = current
            } else {
                name = event.fileName ?? L10n.downloading
            }
            importPhase = .running(
                fileName: name,
                written: event.written ?? 0,
                total: event.total
            )
        case "file_done":
            currentImportDownloaded += 1
            if let local = event.payload["local"] as? String {
                thumbnailLoader.invalidate(path: local)
            }
        case "complete":
            guard event.payload["ok"] as? Bool ?? true else {
                handleImportFailure(from: event)
                return
            }
            let skipped = (event.payload["stats"] as? [String: Any])?["skipped"] as? Int ?? 0
            let downloaded = (event.payload["stats"] as? [String: Any])?["downloaded_files"] as? Int
                ?? currentImportDownloaded
            currentImportDownloaded = downloaded
            importPhase = .completed(downloaded: downloaded, skipped: skipped)
            statusMessage = L10n.importCompleted(downloaded)
            selectedClipIDs.removeAll()
            Task { await reloadCurrentSection() }
        case "cancelled":
            let downloaded = event.payload["downloaded_files"] as? Int ?? currentImportDownloaded
            currentImportDownloaded = downloaded
            importPhase = .cancelled(downloaded: downloaded)
            statusMessage = L10n.importCancelled(downloaded)
            Task { await reloadCurrentSection() }
        case "error":
            handleImportFailure(from: event)
        default:
            break
        }
    }

    private func handleImportFailure(from event: ImportStreamEvent) {
        let failedList = (event.payload["stats"] as? [String: Any])?["failed"] as? [String]
        let message = event.payload["message"] as? String
            ?? failedList?.joined(separator: "; ")
            ?? L10n.importFailed
        importPhase = .failed(message: message)
        statusMessage = message
        Task { await reloadCurrentSection() }
    }

    private func fetchCameraSummary(bridge: PythonBridge, forceRefresh: Bool = false, start: Int = 0) async throws -> [String: Any] {
        let destKey = destinationURL.path

        if !forceRefresh,
           start == 0,
           let cached = cachedCameraSummary,
           cachedCameraSummaryDest == destKey,
           let cachedAt = cachedCameraSummaryAt,
           cached["has_more"] as? Bool != true,
           Date().timeIntervalSince(cachedAt) < summaryCacheTTL {
            AppLogger.log("app_state", "fetchCameraSummary cache_hit", extra: ["dest": destKey])
            return cached
        }

        if start == 0, let existing = cameraSummaryTask {
            AppLogger.log("app_state", "fetchCameraSummary join_inflight")
            return try await existing.value
        }

        let task = Task<[String: Any], Error> { [destinationURL] in
            try await bridge.runJSON(arguments: Self.summaryCLIArguments(
                destPath: destinationURL.path,
                start: start,
                maxPages: start == 0 ? 1 : 1
            ))
        }
        if start == 0 {
            cameraSummaryTask = task
        }
        defer {
            if start == 0 {
                cameraSummaryTask = nil
            }
        }

        do {
            let json = try await task.value
            if start == 0 {
                cachedCameraSummary = json
                cachedCameraSummaryDest = destKey
                cachedCameraSummaryAt = Date()
            }
            return json
        } catch {
            if error is CancellationError {
                throw CancellationError()
            }
            throw error
        }
    }

    private static func summaryCLIArguments(destPath: String, start: Int, maxPages: Int?) -> [String] {
        var args = [
            "-m", "insta360_go3s_wifi.cli", "ui", "summary",
            destPath,
            "--start", "\(start)",
        ]
        if let maxPages {
            args += ["--max-pages", "\(maxPages)"]
        }
        return args
    }

    private func scheduleLoadMoreFiles(seed: [String: Any]) {
        loadMoreTask?.cancel()
        loadMoreTask = Task {
            await loadRemainingCameraFiles(seed: seed)
        }
    }

    private func loadRemainingCameraFiles(seed: [String: Any]) async {
        guard let bridge else { return }
        isLoadingMoreFiles = true
        defer {
            isLoadingMoreFiles = false
            statusMessage = connectionSubtitle(for: selectedSection)
        }

        var merged = seed
        updateRemoteProgress(from: merged)

        while merged["has_more"] as? Bool == true {
            if Task.isCancelled { return }
            let nextStart = merged["list_next_start"] as? Int ?? merged["remote_loaded"] as? Int ?? 0
            do {
                let page = try await AppLogger.timed(
                    "app_state",
                    "fetchCameraSummaryPage",
                    extra: ["start": nextStart]
                ) {
                    try await bridge.runJSON(arguments: Self.summaryCLIArguments(
                        destPath: destinationURL.path,
                        start: nextStart,
                        maxPages: 1
                    ))
                }
                if Task.isCancelled { return }
                merged = mergeSummaryPages(merged, page)
                cachedCameraSummary = merged
                cachedCameraSummaryAt = Date()
                updateRemoteProgress(from: merged)
                applySummary(merged)
            } catch {
                if error is CancellationError { return }
                AppLogger.log("app_state", "loadMoreFiles error", extra: ["error": String(describing: error)])
                statusMessage = L10n.partialLoadFailed(error.localizedDescription)
                return
            }
        }
    }

    private func mergeSummaryPages(_ base: [String: Any], _ page: [String: Any]) -> [String: Any] {
        var merged = base
        let baseMp4 = base["mp4_files"] as? [String] ?? []
        let pageMp4 = page["mp4_files"] as? [String] ?? []
        let allMp4 = baseMp4 + pageMp4

        let imported = Set(base["imported_mp4"] as? [String] ?? [])
            .union(page["imported_mp4"] as? [String] ?? [])
        let pending = allMp4.filter { !imported.contains($0) }

        merged["mp4_files"] = allMp4
        merged["imported_mp4"] = Array(imported).sorted()
        merged["pending_mp4"] = pending
        merged["pending_count"] = pending.count
        merged["imported_count"] = imported.count
        merged["mp4_count"] = allMp4.count
        merged["remote_total"] = page["remote_total"] ?? base["remote_total"]
        merged["remote_loaded"] = page["remote_loaded"] ?? page["list_next_start"]
        merged["list_next_start"] = page["list_next_start"]
        merged["has_more"] = page["has_more"] ?? false
        return merged
    }

    private func updateRemoteProgress(from json: [String: Any]) {
        remoteTotalCount = json["remote_total"] as? Int
        remoteLoadedCount = json["remote_loaded"] as? Int ?? json["list_next_start"] as? Int ?? 0
    }

    private func applySummary(_ json: [String: Any]) {
        let importedSet = Set(json["imported_mp4"] as? [String] ?? [])
        pendingCount = json["pending_count"] as? Int ?? 0

        let mp4Files = json["mp4_files"] as? [String] ?? []
        clips = mp4Files.map { path in
            ClipItem.fromRemote(
                path,
                imported: importedSet.contains(path),
                destination: destinationURL
            )
        }

        statusMessage = connectionSubtitle(for: selectedSection)
        thumbnailLoader.scheduleRemoteBatch(for: clips, destination: destinationURL)
    }

    func connectionSubtitle(for section: SidebarSection) -> String {
        switch section {
        case .camera:
            let imported = clips.filter(\.isImported).count
            let visible = visibleClips.count
            if cameraImportFilter != .all, clips.count > 0 {
                return filteredCameraSummary(
                    visible: visible,
                    total: clips.count,
                    imported: imported,
                    pending: pendingCount
                )
            }
            if let total = remoteTotalCount, total > remoteLoadedCount {
                return L10n.cameraSummaryScanning(
                    count: clips.count,
                    imported: imported,
                    pending: pendingCount,
                    loaded: remoteLoadedCount,
                    total: total
                )
            }
            return L10n.cameraSummary(count: clips.count, imported: imported, pending: pendingCount)
        case .library:
            return L10n.librarySummary(clips.count)
        }
    }

    private func filteredCameraSummary(visible: Int, total: Int, imported: Int, pending: Int) -> String {
        switch cameraImportFilter {
        case .all:
            return L10n.cameraSummary(count: total, imported: imported, pending: pending)
        case .imported:
            return L10n.filteredSummaryImported(visible: visible, total: total)
        case .notImported:
            return L10n.filteredSummaryNotImported(visible: visible, total: total)
        }
    }

    private func updatePendingCount() async {
        guard connection.ok, let bridge else { return }
        do {
            let json = try await fetchCameraSummary(bridge: bridge, forceRefresh: false)
            pendingCount = json["pending_count"] as? Int ?? 0
        } catch {
            // Keep previous pendingCount on transient errors.
        }
    }

    private func beginLoading() -> Int {
        loadGeneration += 1
        isLoading = true
        return loadGeneration
    }

    private func endLoading(_ generation: Int) {
        if isCurrentLoad(generation) {
            isLoading = false
        }
    }

    private func isCurrentLoad(_ generation: Int) -> Bool {
        !Task.isCancelled && generation == loadGeneration
    }

    private func elapsedMs(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: ContinuousClock.now)
        return Double(duration.components.seconds) * 1000.0
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000.0
    }
}
