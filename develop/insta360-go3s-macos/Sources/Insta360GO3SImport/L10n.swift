import Foundation

enum L10n {
    static var language: AppLanguage = .load()

    static var isChinese: Bool {
        language.resolvesToChinese()
    }

    static func pickDirect(isChinese chinese: Bool, zh: String, en: String) -> String {
        chinese ? zh : en
    }

    static func pick(_ zh: String, _ en: String) -> String {
        isChinese ? zh : en
    }

    static var resolvedLocale: Locale {
        language.resolvedLocale
    }

    // MARK: - App branding

    static var appName: String { pick("GO 3S 导入", "GO 3S Import") }
    static var menuBarTitle: String { pick("GO 3S", "GO 3S") }
    static var defaultWifiSSID: String { pick("GO 3S Wi‑Fi", "GO 3S Wi‑Fi") }

    // MARK: - Camera filter

    static var filterAll: String { pick("全部", "All") }
    static var notImported: String { pick("未导入", "Not Imported") }
    static var filterLabel: String { pick("筛选", "Filter") }
    static var filterEmptyImportedTitle: String { pick("没有已导入素材", "No imported clips") }
    static var filterEmptyImportedSubtitle: String {
        pick("当前筛选下没有已同步到 Mac 的相机视频", "No camera clips synced to your Mac match this filter")
    }
    static var filterEmptyNotImportedTitle: String { pick("没有待导入素材", "No clips to import") }
    static var filterEmptyNotImportedSubtitle: String {
        pick("所有相机视频已同步到 Mac", "All camera clips are already on your Mac")
    }
    static var allSyncedTitle: String { filterEmptyNotImportedTitle }
    static var allSyncedSubtitle: String { filterEmptyNotImportedSubtitle }

    // MARK: - Sidebar

    static var sidebarMedia: String { pick("媒体", "Media") }
    static var sidebarBrowseHint: String { pick("浏览相机与本地素材", "Browse camera and local clips") }
    static var sidebarCamera: String { pick("相机", "Camera") }
    static var sidebarLibrary: String { pick("媒体库", "Library") }
    static var sidebarCameraSubtitle: String {
        pick("相机视频；可用筛选查看已导入 / 未导入", "Camera clips; filter by imported or not imported")
    }
    static var sidebarLibrarySubtitle: String {
        pick("已保存到本地的视频", "Clips saved locally")
    }
    static var connected: String { pick("相机已连接", "Camera connected") }
    static var notConnected: String { pick("未连接", "Not connected") }
    static var wifiOnlyConnected: String {
        pick("仅 WiFi 已连接", "WiFi only — pair app + Quick File Transfer")
    }
    static func refreshConnectionHelp(connected: Bool) -> String {
        connected
            ? pick("刷新连接与文件列表", "Refresh connection and file list")
            : pick("检测 WiFi / TCP 连接", "Check Wi‑Fi / TCP connection")
    }

    // MARK: - Status badges

    static var imported: String { pick("已导入", "Imported") }
    static var pendingImport: String { notImported }
    static var unknownDate: String { pick("未知日期", "Unknown date") }

    // MARK: - Toolbar & loading

    static func selectedCount(_ count: Int) -> String { pick("已选 \(count) 项", "\(count) selected") }
    static var refresh: String { pick("刷新", "Refresh") }
    static var checkConnection: String { pick("检测连接", "Check Connection") }
    static var importSelected: String { pick("导入选中", "Import Selected") }
    static var importNew: String { pick("导入新素材", "Import New") }
    static var cancel: String { pick("取消", "Cancel") }
    static var diagnosing: String { pick("正在检测连接…", "Checking connection…") }
    static func loadingMoreFiles(loaded: Int, total: Int) -> String {
        pick("正在加载后续文件 (\(loaded)/\(total))…", "Loading more files (\(loaded)/\(total))…")
    }
    static var loadingMoreFilesGeneric: String { pick("正在加载后续文件…", "Loading more files…") }
    static var loadingFileList: String { pick("正在读取相机文件列表…", "Reading camera file list…") }
    static var refreshingList: String { pick("正在刷新列表…", "Refreshing list…") }
    static var refreshing: String { pick("正在刷新…", "Refreshing…") }
    static var notConnectedHint: String {
        pick("未连接 — 需手机 App 配对 + Quick File Transfer", "Not connected — pair the app and enable Quick File Transfer")
    }
    static var connectedNoVideos: String { pick("已连接，相机上暂无视频", "Connected, no videos on camera") }
    static func cameraSummary(count: Int, imported: Int, pending: Int) -> String {
        pick(
            "相机上 \(count) 个视频 · 已导入 \(imported) · 待导入 \(pending)",
            "\(count) on camera · \(imported) imported · \(pending) pending"
        )
    }
    static func cameraSummaryScanning(count: Int, imported: Int, pending: Int, loaded: Int, total: Int) -> String {
        pick(
            "相机上 \(count) 个视频 · 已导入 \(imported) · 待导入 \(pending) · 已扫描 \(loaded)/\(total)",
            "\(count) on camera · \(imported) imported · \(pending) pending · scanned \(loaded)/\(total)"
        )
    }
    static func filteredSummaryImported(visible: Int, total: Int) -> String {
        pick("已导入 \(visible) / \(total) 个", "\(visible) imported of \(total)")
    }
    static func filteredSummaryNotImported(visible: Int, total: Int) -> String {
        pick("未导入 \(visible) / \(total) 个", "\(visible) not imported of \(total)")
    }
    static var libraryEmpty: String { pick("本地媒体库为空", "Local library is empty") }
    static func librarySummary(_ count: Int) -> String {
        pick("媒体库 \(count) 个本地视频", "Library · \(count) local videos")
    }

    // MARK: - App state

    static var initialStatus: String {
        pick(
            "需手机 Insta360 App 连接相机，并开启 Quick File Transfer",
            "Pair the Insta360 app on your phone and enable Quick File Transfer"
        )
    }
    static var notConnectedCamera: String {
        pick("未连接相机 — 需 App 配对 + Quick File Transfer", "Camera not connected — pair app + Quick File Transfer")
    }
    static var previewNeedsConnection: String { pick("未连接相机，无法流式预览", "Camera not connected; streaming preview unavailable") }
    static var previewUnavailable: String {
        pick("无法预览：文件不在本地且没有远程路径", "Cannot preview: file is not local and has no remote path")
    }
    static var selectClipToPreview: String { pick("请先选中要预览的素材", "Select a clip to preview") }
    static var chooseImportFolder: String { pick("选择导入目标文件夹", "Choose import destination folder") }
    static var selectUnimportedFirst: String { pick("请先选择尚未导入的素材", "Select clips that are not imported yet") }
    static var cancelling: String { pick("正在取消…", "Cancelling…") }
    static var preparing: String { pick("准备中…", "Preparing…") }
    static var downloading: String { pick("下载中", "Downloading") }
    static func importCompleted(_ count: Int) -> String { pick("导入完成：\(count) 个文件", "Import complete: \(count) files") }
    static func importCancelled(_ count: Int) -> String {
        pick("导入已取消（\(count) 个文件已保存，可续传）", "Import cancelled (\(count) files saved; resume supported)")
    }
    static var importCancelledShort: String { pick("导入已取消", "Import cancelled") }
    static var importFailed: String { pick("导入失败", "Import failed") }
    static func partialLoadFailed(_ detail: String) -> String {
        pick("部分文件加载失败：\(detail)", "Failed to load some files: \(detail)")
    }
    static func writeImportListFailed(_ detail: String) -> String {
        pick("无法写入导入列表：\(detail)", "Could not write import list: \(detail)")
    }
    static var importNeedsPairing: String {
        pick("请先完成 App 配对与 Quick File Transfer", "Complete app pairing and Quick File Transfer first")
    }

    // MARK: - Preview

    static var previewRemoteTitle: String { pick("相机流式预览", "Camera stream preview") }
    static var close: String { pick("关闭", "Close") }
    static var previewLoading: String { pick("正在从相机加载…", "Loading from camera…") }
    static var previewNoItem: String { pick("无法创建播放项", "Could not create player item") }
    static var previewStreamFailed: String { pick("无法从相机流式播放", "Could not stream from camera") }

    // MARK: - Menu

    static var menuAbout: String { pick("关于 GO 3S Import", "About GO 3S Import") }
    static var menuHide: String { pick("隐藏 GO 3S Import", "Hide GO 3S Import") }
    static var menuHideOthers: String { pick("隐藏其他", "Hide Others") }
    static var menuShowAll: String { pick("显示全部", "Show All") }
    static var menuEdit: String { pick("编辑", "Edit") }
    static var menuUndo: String { pick("撤销", "Undo") }
    static var menuRedo: String { pick("重做", "Redo") }
    static var menuCut: String { pick("剪切", "Cut") }
    static var menuCopy: String { pick("拷贝", "Copy") }
    static var menuPaste: String { pick("粘贴", "Paste") }
    static var menuSelectAllEdit: String { pick("全选", "Select All") }
    static var menuWindow: String { pick("窗口", "Window") }
    static var menuMinimize: String { pick("最小化", "Minimize") }
    static var menuZoom: String { pick("缩放", "Zoom") }
    static var menuBringAllToFront: String { pick("全部置于前台", "Bring All to Front") }
    static var menuHelp: String { pick("帮助", "Help") }
    static var menuHelpItem: String {
        pick("GO 3S Import 帮助", "GO 3S Import Help")
    }
    static var menuFile: String { pick("文件", "File") }
    static var menuView: String { pick("视图", "View") }
    static var menuSelect: String { pick("选择", "Select") }
    static var menuLanguage: String { pick("语言", "Language") }
    static var chooseFolder: String { pick("选择导入文件夹…", "Choose Import Folder…") }
    static var importSelectedMenu: String { pick("导入选中素材", "Import Selected Clips") }
    static var revealInFinder: String { pick("在 Finder 中显示", "Reveal in Finder") }
    static var openPerfLog: String { pick("打开性能日志", "Open Performance Log") }
    static var selectAll: String { pick("全选", "Select All") }
    static var deselectAll: String { pick("取消全选", "Deselect All") }
    static var preview: String { pick("预览", "Preview") }
    static var openMainWindow: String { pick("打开主窗口", "Open Main Window") }
    static var openMediaFolder: String { pick("打开媒体文件夹", "Open Media Folder") }
    static var refreshStatus: String { pick("刷新状态", "Refresh Status") }
    static var quit: String { pick("退出", "Quit") }
    static var importing: String { pick("正在导入", "Importing") }
    static func connectGO3SWifi(_ ssid: String) -> String {
        pick("请连接 GO 3S WiFi", "Connect to GO 3S Wi‑Fi") + (ssid.isEmpty ? "" : " · \(ssid)")
    }

    // MARK: - Progress

    static func importDoneDetail(downloaded: Int, skipped: Int) -> String {
        pick("导入完成：\(downloaded) 个文件，跳过 \(skipped) 个", "Import complete: \(downloaded) files, \(skipped) skipped")
    }
    static func importCancelledDetail(_ downloaded: Int) -> String {
        pick("导入已取消：已保存 \(downloaded) 个文件（未完成文件可续传）", "Import cancelled: \(downloaded) files saved (resume supported)")
    }

    // MARK: - Thumbnails

    static func generatingRemoteThumbnails(done: Int, total: Int) -> String {
        pick("正在生成远程缩略图 (\(done)/\(total))…", "Generating remote thumbnails (\(done)/\(total))…")
    }

    static func pendingMenuLabel(_ count: Int) -> String {
        pick("\(count) 个新素材待导入", "\(count) new clips pending")
    }

    // MARK: - Formatters

    static func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Python bridge errors

    static var cliRootNotFound: String {
        pick(
            "找不到 insta360-go3s-wifi CLI 目录。请设置 INSTA360_CLI_ROOT 环境变量。",
            "insta360-go3s-wifi CLI not found. Set INSTA360_CLI_ROOT."
        )
    }
    static var pythonMissing: String {
        pick(
            "找不到 Python 虚拟环境 (.venv/bin/python)。",
            "Python virtual environment (.venv/bin/python) not found."
        )
    }
    static var importCancelledBridge: String { pick("导入已取消", "Import cancelled") }

    static func importExitCode(_ code: Int32) -> String {
        pick("导入进程退出码 \(code)", "Import exited with code \(code)")
    }
}
