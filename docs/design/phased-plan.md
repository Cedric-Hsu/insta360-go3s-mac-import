# 分期实施计划

## Phase 1：CLI 实机验证（1–2 天）

**目标**：在你自己的 GO 3S 上跑通列目录 + 下载。

1. GO 3S 开机，Mac 连接 `GO 3S xxxxxx.OSC`  
2. `pip install insta360`  
3. 运行测试脚本：`open()` → `get_camera_files_list_bundle()` → `download_file()`  
4. 记录结果到 [tests/GO3S_COMPAT.md](../../tests/GO3S_COMPAT.md)

**产出**：兼容结论；若不兼容则 fork 最小 WiFi 客户端。

---

## Phase 2：开源 CLI 工具（1–2 周）

**目标**：可发布的命令行工具 `insta360-go3s-wifi`。

```bash
insta360-go3s-wifi import --dest ~/Movies/GO3S --new-only
```

- Python 核心（依赖或 vendored whitebox 逻辑）  
- 本地 JSON/SQLite 索引去重  
- `pyproject.toml`、MIT LICENSE、基础 CI  

**UI（可选）**：Tauri 菜单栏或 SwiftUI + Python 子进程。

---

## Phase 3：体验优化（可选）

| 能力 | 说明 |
|------|------|
| BLE 唤醒 | `OPEN_CAMERA_WIFI`，参考 insta360ctl |
| 防休眠 | TCP KeepAlive + 下载期间持续通信 |
| Station 模式 | 相机加入 Mac 热点，避免断外网 |
| Keychain | 保存 WiFi 密码 |

---

## 流程概览

```mermaid
%%{init: {
 "theme": "base",
 "themeVariables": {
 "darkMode": true,
 "background": "#1a1d23",
 "primaryColor": "#2d3748",
 "primaryTextColor": "#e2e8f0",
 "primaryBorderColor": "#64748b",
 "lineColor": "#64748b",
 "textColor": "#e2e8f0",
 "mainBkg": "#2d3748",
 "nodeBorder": "#64748b"
 }
}}%%
flowchart LR
 P1[Phase 1 CLI 验证]
 P2[Phase 2 开源 CLI]
 P3[Phase 3 BLE 与 Station]
 P1 --> P2 --> P3
 classDef start fill:#1e3a5f,stroke:#60a5fa,color:#e2e8f0,stroke-width:1px
 classDef done fill:#14532d,stroke:#4ade80,color:#e2e8f0,stroke-width:1px
 class P1 start
 class P3 done
```
