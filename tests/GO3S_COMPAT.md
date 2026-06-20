# GO 3S 兼容性记录

> 实机测试后填写。每项测试请记录：**固件版本、日期、结果、备注**。

## 环境

| 字段 | 值 |
|------|-----|
| 相机型号 | GO 3S |
| 相机固件 | _待填_ |
| macOS 版本 | _待填_ |
| Mac 型号 | _待填_ |
| WiFi 密码类型 | 默认 / 自定义 |
| 测试人 | _待填_ |
| 测试日期 | _待填_ |

## 测试结果

| 项目 | 结果 | 备注 |
|------|------|------|
| Mac 连接 GO 3S WiFi AP | ⬜ | |
| ping 192.168.42.1 | ⬜ | |
| TCP 6666 Sync 握手 | ⬜ | |
| GET_FILE_LIST 列目录 | ⬜ | |
| HTTP 80 下载小 MP4 | ⬜ | |
| HTTP 80 下载 LRV | ⬜ | |
| 并行下载大文件 | ⬜ | |
| 断点续传 | ⬜ | |
| whitebox pip 包可用 | ⬜ | |

图例：✅ 通过 · ❌ 失败 · ⬜ 未测

## 失败日志

_粘贴命令输出或错误栈_

## 结论

_是否进入 Phase 2 开发_

## Phase 1 auto-run

- Date: 2026-06-20 08:37:13
- Overall: FAIL

| Step | Result | Detail |
|------|--------|--------|
| WiFi SSID | FAIL | connected to `<redacted>` |
| ping camera | PASS | ping 192.168.42.1 OK |
| HTTP DCIM | FAIL | HTTP HEAD failed http://192.168.42.1/DCIM/Camera01/:  |
| TCP open | FAIL | Failed to open TCP connection to 192.168.42.1:6666: Command seq 0 did not succeed in 20 seconds |

## Phase 1 auto-run

- Date: 2026-06-20 08:42:25
- Overall: FAIL

| Step | Result | Detail |
|------|--------|--------|
| WiFi / camera link | PASS | ping 192.168.42.1 OK; SSID=<redacted> |
| ping camera | PASS | ping 192.168.42.1 OK |
| TCP SYNC + open | FAIL | SYNC handshake failed (no echo from camera) |
| hint | FAIL | Try Action Pod Quick File Transfer, or connect Insta360 app once via BLE |
