# Insta360 GO 3S Import (macOS)

SwiftUI 桌面应用，界面参考 **Apple iMovie** 深色媒体浏览器布局。底层通过子进程调用 Python CLI（`insta360-go3s-wifi`）。

## 界面结构（iMovie 风格）

| 区域 | 说明 |
|------|------|
| 左侧边栏 | 媒体库导航：**相机** / **媒体库** |
| 相机筛选 | 全部 / 已导入 / 未导入（替代原「待导入」页） |
| 顶部工具栏 | 标题、刷新、目标文件夹、绿色「导入新素材」、取消 |
| 主浏览区 | 浅色背景 + 白色卡片网格，**真实 MP4 缩略图**（本地已有文件） |
| 底部进度条 | 导入进度；支持取消，未完成文件可 HTTP 续传 |
| **菜单栏图标** | 状态栏 `GO 3S` 图标：连接状态、快捷导入、打开主窗口 |

## 依赖（开发者构建）

1. **Xcode Command Line Tools** 或 Xcode（`swift build`）
2. 已配置好的 Python CLI：`../insta360-go3s-wifi/.venv`

```bash
cd ../insta360-go3s-wifi
python3 -m venv .venv
.venv/bin/pip install -e '.[dev]'
```

## 构建与运行（开发）

```bash
cd develop/insta360-go3s-macos
./build.sh
./run.sh
```

若 CLI 不在默认相对路径，设置：

```bash
export INSTA360_CLI_ROOT="/path/to/develop/insta360-go3s-wifi"
./run.sh
```

## 打包分发（给其他人安装）

在**本机**先确保 Python venv 可用，然后：

```bash
cd develop/insta360-go3s-macos
chmod +x package.sh
./package.sh --dmg
```

产出：

| 文件 | 说明 |
|------|------|
| `dist/Insta360 GO 3S Import.app` | 含 Swift 应用 + 内置 Python CLI |
| `dist/Insta360 GO 3S Import.dmg` | 可拖入「应用程序」的安装镜像 |

**首次打开**：若 macOS 提示无法验证开发者，请 **右键应用 → 打开**（当前为 ad-hoc 签名，未上架 App Store）。

**系统要求**：macOS 13+，需安装 **Xcode Command Line Tools**（提供 `/usr/bin/python3`）。打包机器与目标机器 CPU 架构一致为佳（Apple Silicon 或 Intel）。

## 设置

- **语言**：菜单 **Insta360 GO 3S Import → Settings…**（或 `⌘,`）→ 通用 → 语言（跟随系统 / 简体中文 / English）
- **导入文件夹**：设置 → 存储

## 使用流程

1. GO 3S 开机，手机 **Insta360 App** 蓝牙配对
2. Action Pod 开启 **Quick File Transfer**
3. Mac 连接 `GO 3S xxxxxx.OSC` Wi‑Fi（密码在 Action Pod：**设置 → Wi‑Fi 信息** 查看，不一定是 88888888）
4. 启动本应用 → **相机** 页可筛选「全部 / 已导入 / 未导入」
5. 点击 **检测连接** / **导入新素材** → 底部显示进度
6. 「媒体库」查看已下载到 `~/Movies/GO3S` 的文件

## Python UI API

应用调用 `insta360-go3s-wifi ui` 子命令（stdout JSON / NDJSON）：

| 命令 | 输出 |
|------|------|
| `ui connection` | 连接状态 JSON |
| `ui list-remote` | 相机文件列表 |
| `ui pending DEST` | 待导入列表 |
| `ui import DEST` | NDJSON 进度流 + complete |
| `ui index DEST` | 本地索引 |
| `ui library DEST` | 本地媒体文件 |

## License

MIT
