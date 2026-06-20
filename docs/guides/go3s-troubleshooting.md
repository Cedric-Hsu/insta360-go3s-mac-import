# GO 3S Phase 1 故障排除

## 你的测试结果解读（2026-06-20）

| 步骤 | 结果 | 含义 |
|------|------|------|
| ping 192.168.42.1 | PASS | Mac 已连上相机 WiFi 热点 |
| WiFi SSID FAIL | 误报 | macOS 将 SSID 显示为 `<redacted>`，不代表未连接 |
| HTTP DCIM FAIL | 常见 | 目录 URL 往往不支持 HEAD；不代表文件服务不可用 |
| TCP 6666 FAIL | 关键 | 控制通道无响应，无法列文件/下载 |

**结论：** 网络层已通，但 **GO 3S 的文件传输服务（TCP 6666）未就绪**。

---

## 最可能原因

GO 3S 与 X3/X4 不同：仅连 WiFi 可能只开放 ping/telnet，**文件传输协议需在 Action Pod 或 App 侧唤起**。

请按顺序尝试：

### 方法 A：Quick File Transfer（推荐）

1. GO 3S 放入 Action Pod，开机  
2. Mac 连接 `GO 3S xxxxxx.OSC` WiFi  
3. 在 Action Pod **相册**选 1 个短片 → 点 **Quick File Transfer**（右下角）  
4. **保持该界面不要退出**  
5. 另开终端运行：

```bash
source .venv/bin/activate
insta360-go3s-wifi diagnose
insta360-go3s-wifi verify --skip-download
```

### 方法 B：先用官方 App 唤醒

1. iPhone 用 Insta360 App 蓝牙连接 GO 3S 一次  
2. App 内随便打开相册预览  
3. 再让 Mac 连相机 WiFi，重跑 `verify`

### 方法 C：确认相机 WiFi 已开

Action Pod / 相机：**Settings → WiFi → 开启**

---

## 更新后的 CLI（已修复）

项目已从 whitebox `insta360` 0.1.2（缺少 `download_file`，且 `open()` 会卡死）切换为 **GO 3S 专用同步客户端**。

重新安装并测试：

```bash
cd develop/insta360-go3s-wifi
source .venv/bin/activate
pip install -e ".[dev]"

insta360-go3s-wifi diagnose
insta360-go3s-wifi verify --save-report ../../tests/GO3S_COMPAT.md
```

新增命令：

| 命令 | 作用 |
|------|------|
| `diagnose` | 检测 TCP 6666/80、osc/info |
| `verify` | SYNC + 列目录 + 下载最小 MP4 |

---

## 若仍然 TCP 失败

1. 运行 `insta360-go3s-wifi diagnose`，看 **TCP 6666 reachable** 是否为 PASS  
2. 若 TCP 通但 SYNC 失败：记录固件版本，Issue 反馈  
3. 若 TCP 不通：几乎确定需 Quick Transfer / App 唤起，或该固件不支持 Mac 直连

---

## 终端粘贴提示

不要整段复制带 `#` 注释的多行命令到 zsh；请逐条执行：

```bash
insta360-go3s-wifi probe
insta360-go3s-wifi verify --save-report ../../tests/GO3S_COMPAT.md
insta360-go3s-wifi list
```
