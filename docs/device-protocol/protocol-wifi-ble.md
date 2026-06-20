# 协议概要：WiFi 与 BLE

> 摘要自社区文档（insta360ctl、whitebox 等），非 Insta360 官方规范。

## WiFi 模式

| 模式 | 说明 |
|------|------|
| AP | 相机开热点，客户端连 SSID，IP 192.168.42.1 |
| Station | 相机加入现有 WiFi，IP 由 DHCP 分配，通知码 8232 |

切换至 Station：命令 **112** `SET_WIFI_CONNECTION_INFO`（SSID + 密码）。

---

## TCP 6666 要点

1. **Sync**：连接后发送 magic `syNceNdinS`，相机 echo 相同内容  
2. **KeepAlive**：约每 2 秒发送，约 10 秒无数据会断连  
3. **MESSAGE 包**：12 字节头 + Protobuf 体  
4. **列文件**：命令码 **13** `GET_FILE_LIST`

### 常用 WiFi 命令码

| 码 | 名称 | 用途 |
|----|------|------|
| 13 | GET_FILE_LIST | 文件列表 |
| 33 | OPEN_CAMERA_WIFI | 打开 WiFi |
| 34 | CLOSE_CAMERA_WIFI | 关闭 WiFi |
| 112 | SET_WIFI_CONNECTION_INFO | 加入现有网络 |
| 113 | GET_WIFI_CONNECTION_INFO | 查询 WiFi 状态 |

---

## HTTP 文件下载

- URL 形式：`http://{camera_ip}/DCIM/Camera01/{filename}`  
- 支持 **HTTP Range**，可断点续传  
- whitebox 实现对大文件使用并行 Range 写 `.part` 后原子 rename  

---

## BLE（GO 2 / GO 3 / GO 3S）

GO 系列使用 **Go2BlePacket** 封装（5 字节头 + 16 字节内头 + Protobuf + CRC16）。

服务 UUID：**BE80**（App 连相机 GATT Server）。

Phase 3 可选能力：

- `OPEN_CAMERA_WIFI` 唤起 WiFi  
- KeepAlive / 授权流程，减少相机休眠  

GO 3 固件与「官方枚举」存在偏差，见 insta360ctl `protocol.md` 中 **GO 3 Firmware Deviations**。  
**建议 MVP 仅使用 GET_FILE_LIST + HTTP GET**，避免 DELETE 等危险命令。

---

## 参考

- [insta360ctl protocol.md](https://github.com/xaionaro-go/insta360ctl/blob/main/doc/protocol.md)
- [whitebox RTMP API](https://insta360.whitebox.aero/api-reference/rtmp-module/)
