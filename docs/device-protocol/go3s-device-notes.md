# GO 3S 设备要点

## 基本信息

| 项目 | 说明 |
|------|------|
| 目标机型 | Insta360 GO 3S |
| WiFi | **5GHz**（802.11a/n/ac），BLE 5.0 |
| SSID 格式 | `GO 3S XXXXXX.OSC`（序列号后 6 位） |
| 默认 WiFi 密码 | 常见为 `88888888`，可在 App 或相机「WiFi Settings」修改 |
| AP 模式 IP | 192.168.42.1 |
| 控制端口 | TCP 6666 |
| 文件 HTTP | 端口 80 |

---

## 素材格式

### 视频

- 机内均为 **MP4**
- 多数模式同时生成 **LRV** 低清预览轨
- **导入时应 MP4 + 同名 LRV 成组下载**

### 照片

- 机内 **INSP**；导出 JPG 需 Insta360 App / Studio

### 存储路径

相机内路径示例（HTTP 与 U 盘模式一致）：

- 目录：`DCIM/Camera01/`
- 示例：`VID_20250620_120000.mp4`、`VID_20250620_120000.lrv`

---

## 休眠与 Action Pod

- 相机约 **3 分钟**无操作可能关机（可配置）
- 开发/调试时可通过 TCP KeepAlive 或保持连接避免断连
- **Quick File Transfer** 在 Action Pod 相册界面触发；本项目计划绕过选片 UI，直接拉取目录

---

## 官方 Quick File Transfer

- 适用：GO 3S、GO Ultra
- 流程：Action Pod 选片 → 点 Quick Transfer → 手机 BLE + WiFi 接收
- 官方宣称最高约 **20 MB/s**（视环境而定）
- 详见 [go3s-quick-transfer.md](./go3s-quick-transfer.md)

---

## USB 对比（备用路径）

| 方式 | 速度参考 | 说明 |
|------|----------|------|
| USB 原装线 | 约 36 MB/s | 官方 GO 3S 文档 |
| WiFi Quick Transfer | 约 20 MB/s | 官方上限参考 |

USB 需 U-Disk 模式；GO 3S 可设 USB 密码。

---

## 参考资料

- [GO 3S 文件格式](https://onlinemanual.insta360.com/go3s/en-us/operating_tutorials/storage/file-format)
- [GO 3S WiFi 规格](https://onlinemanual.insta360.com/go3s/en-us/specs/camera-wifi/wifi)
- [GO 系列 telnet 说明（社区）](https://github.com/enekochan/insta360-go-firmware-tool/blob/master/docs/telnet_connection.md)
