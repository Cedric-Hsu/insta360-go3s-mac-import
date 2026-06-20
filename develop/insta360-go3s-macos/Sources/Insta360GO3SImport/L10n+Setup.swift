import Foundation

extension L10n {
    // MARK: - Settings

    static var settingsGeneral: String { pick("通用", "General") }
    static var settingsStorage: String { pick("存储", "Storage") }
    static var settingsAdvanced: String { pick("高级", "Advanced") }
    static var settingsImportFolder: String { pick("导入文件夹", "Import folder") }
    static var settingsTitle: String { pick("设置", "Settings") }

    // MARK: - Empty state / setup guide

    static var setupStepPodPower: String {
        pick("GO 3S 放入 Action Pod 并开机", "Power on GO 3S inside the Action Pod")
    }
    static var setupStepPhoneApp: String {
        pick(
            "手机打开 Insta360 App，蓝牙连接 GO 3S（Pod 上点确认；需开蓝牙 / Wi‑Fi / 定位）",
            "Open Insta360 app on your phone and pair GO 3S over Bluetooth (confirm on Pod; enable Bluetooth, Wi‑Fi, and Location)"
        )
    }
    static var setupStepMacWifi: String {
        pick(
            "Mac 连接 Wi‑Fi：GO 3S xxxxxx.OSC（密码在 Action Pod：设置 → Wi‑Fi 信息 中查看，非固定 88888888）",
            "On Mac, join Wi‑Fi GO 3S xxxxxx.OSC (password is shown on Action Pod: Settings → Wi‑Fi info — not always 88888888)"
        )
    }
    static var setupStepQuickTransfer: String {
        pick(
            "Action Pod：相册 → 任选一段视频 → 开启 Quick File Transfer，并保持该界面",
            "On Action Pod: Album → pick any clip → enable Quick File Transfer and keep that screen open"
        )
    }
    static var setupStepCheckConnection: String {
        pick("回到本 Mac 应用，点击「检测连接」", "Return to this Mac app and click Check Connection")
    }

    static var setupAppRequirementCallout: String {
        pick(
            "重要：仅 Mac 连接相机 Wi‑Fi 不够。Action Pod 相册与 Quick File Transfer 需手机 Insta360 App 先连上；若 Pod 提示「请连接至 App」，请完成上一步 App 配对后再试。",
            "Important: connecting Mac to camera Wi‑Fi alone is not enough. Quick File Transfer requires the Insta360 app on your phone first. If the Pod says “Connect to App”, finish phone pairing and retry."
        )
    }

    static var setupSessionNote: String {
        pick(
            "App 保持连接或刚连过即可；Mac 屏幕可熄灭；Action Pod 需停留在 Quick File Transfer。",
            "The phone app can stay connected or have connected recently; Mac display may sleep; Action Pod must stay on Quick File Transfer."
        )
    }

    static var emptyConnectionStepsHeading: String { pick("连接步骤", "Connection steps") }
    static var emptyTroubleshootHeading: String { pick("排查建议", "Troubleshooting") }
    static var emptyNextStepsHeading: String { pick("接下来", "Next steps") }
    static var emptyImportMethodsHeading: String { pick("导入方式", "How to import") }

    static var emptyNotConnectedTitle: String { pick("尚未连接 GO 3S", "GO 3S not connected") }
    static var emptyNotConnectedSubtitle: String {
        pick(
            "需手机 App 配对 + Quick File Transfer；完成下方步骤后点「检测连接」",
            "Pair the phone app and enable Quick File Transfer, then click Check Connection"
        )
    }

    static var emptyNoVideosTitle: String { pick("相机上没有视频", "No videos on camera") }
    static var emptyNoVideosSubtitle: String { pick("已连接，但未发现 MP4", "Connected, but no MP4 files were found") }

    static var emptyPendingBlockedTitle: String { pick("无法查看待导入", "Cannot view pending clips") }
    static var emptyPendingBlockedSubtitle: String {
        pick(
            "需手机 App 配对 + Quick File Transfer，不能只连 Mac Wi‑Fi",
            "Pair the phone app and enable Quick File Transfer — Mac Wi‑Fi alone is not enough"
        )
    }

    static var emptyNoPendingTitle: String { pick("没有待导入素材", "No pending clips") }
    static var emptyNoPendingSubtitle: String { pick("所有相机视频已同步到 Mac", "All camera clips are already on your Mac") }

    static var emptyLibraryTitle: String { pick("媒体库为空", "Library is empty") }
    static var emptyLibrarySubtitle: String { pick("本地还没有 MP4 文件", "No local MP4 files yet") }

    static var emptyDefaultFolderNote: String { pick("默认：~/Movies/GO3S", "Default: ~/Movies/GO3S") }

    static var emptyTroubleshootAppConnected: String {
        pick("确认手机 Insta360 App 仍与相机连接", "Confirm the Insta360 app is still connected to the camera")
    }
    static var emptyTroubleshootQFT: String {
        pick("确认 Action Pod 仍在 Quick File Transfer", "Confirm Action Pod is still in Quick File Transfer")
    }
    static var emptyTroubleshootRecord: String {
        pick("在相机上录制至少一段视频", "Record at least one clip on the camera")
    }
    static var emptyTroubleshootRefresh: String {
        pick("点击「刷新列表」重新加载相机文件", "Click Refresh to reload the camera file list")
    }

    static var emptyNextLibrary: String {
        pick("在「媒体库」查看已下载视频", "Open Library to view downloaded clips")
    }
    static var emptyNextNewClips: String {
        pick("新拍摄素材会出现在相机列表", "New recordings appear in the camera list")
    }
    static var emptyFilterTryAll: String {
        pick("切换到「全部」查看所有相机视频", "Switch to All to view every camera clip")
    }

    static var emptyImportWireless: String {
        pick(
            "手机 Insta360 App 连接相机 → Quick File Transfer → Mac 无线导入",
            "Phone Insta360 app → Quick File Transfer → import wirelessly on Mac"
        )
    }
    static var emptyImportChooseFolder: String { pick("或选择已有文件夹", "Or choose an existing folder") }

    static var emptyCameraReachable: String { pick("相机服务可达", "Camera service reachable") }
    static var emptyCameraNotReachable: String { pick("尚未连接相机", "Camera not connected yet") }

    static var emptyDiagnosing: String {
        pick("正在检测 Wi‑Fi、ping、TCP、HTTP…", "Checking Wi‑Fi, ping, TCP, HTTP…")
    }

    static var emptyRefreshList: String { pick("刷新列表", "Refresh list") }
    static var emptyWifiSettings: String { pick("Wi‑Fi 设置", "Wi‑Fi Settings") }
    static var emptyChooseMediaFolder: String { pick("选择媒体文件夹", "Choose media folder") }

    static var diagnoseResultsTitle: String { pick("检测结果", "Diagnostics") }
    static var diagnosePassed: String { pick("通过", "Passed") }
    static var diagnoseFailed: String { pick("未通过", "Failed") }
    static var unknownCheckItem: String { pick("未知检查项", "Unknown check") }

    static func diagnoseMoreSteps(_ count: Int) -> String {
        pick("还有 \(count) 项检查…", "\(count) more checks…")
    }

    static var diagnoseConnectedHint: String {
        pick(
            "相机已连接。若列表为空或状态不对，请点击工具栏「刷新」。",
            "Camera connected. If the list is empty or stale, click Refresh in the toolbar."
        )
    }
    static var diagnoseStepConnectionOk: String {
        pick("连接状态：相机服务可达", "Connection: camera service reachable")
    }
    static var diagnoseStepListReloaded: String {
        pick("已重新加载相机文件列表", "Camera file list reloaded")
    }

    static var jsonParseFailed: String { pick("JSON 解析失败", "JSON parse failed") }

    static var cliNotReady: String {
        pick("CLI 未就绪，请检查 Python 环境", "CLI not ready — check the bundled Python environment")
    }
}
