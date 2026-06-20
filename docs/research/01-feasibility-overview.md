# 总体可行性分析

## 结论

开发一款将 Insta360 设备素材传送到 Mac 的软件 **具备可行性**，但实现路径与官方支持程度差异很大。

| 方案 | Mac 原生 | 无线 | 难度 | 官方支持 | 推荐度 |
|------|----------|------|------|----------|--------|
| USB U 盘模式 + 自动拷贝 | ✅ | ❌ | 低 | ✅ | ⭐⭐⭐⭐⭐ |
| Desktop SDK（USB） | ❌ 仅 Win/Linux | ❌ | 中高 | ✅ 需企业申请 | ⭐⭐⭐ |
| WiFi 私有协议 | ✅ | ✅ | 高 | ❌ | ⭐⭐ |
| 封装官方 App 流程 | ✅ | 部分 | 很低 | ✅ | ⭐⭐⭐ |

**本项目选择**：WiFi 无线 + GO 3S + 个人开源工具。

---

## 方案一：USB U 盘模式（最稳）

官方流程：USB-C 连接 Mac → 选择 U-Disk / File Transfer → 从 `DCIM/Camera01` 复制文件。

- 无需 SDK，可做「智能文件管理器」：检测挂载、增量拷贝、去重、整理
- 限制：必须插线；连接后相机不可继续拍摄；一次一台

---

## 方案二：官方 Desktop SDK

Camera SDK 提供 `GetCameraFilesList`、`DownloadCameraFile`（内部 HTTP 服务，默认端口 9099）等能力。

**硬限制：**

1. **不支持 macOS**，仅 Windows 7+ 与 Ubuntu 22.04
2. 需企业申请 SDK、NDA、签署 EULA

---

## 方案三：WiFi 无线（本项目方向）

- 官方：**相机与电脑不支持无线连接**（手机 App 支持 WiFi 传文件）
- 社区：TCP 6666 控制 + HTTP 80 下载，已有 Python 实现
- 详见 [02-wifi-transfer-feasibility.md](./02-wifi-transfer-feasibility.md)

---

## 参考资料

- [Insta360 文件传输官方说明](https://onlinemanual.insta360.com/app/en-us/operation-tutorial/file-transfer/file-transfer-with-computer)
- [Camera SDK C++](https://github.com/Insta360Develop/Desktop-CameraSDK-Cpp)
- [SDK 申请](https://www.insta360.com/sdk/apply)
