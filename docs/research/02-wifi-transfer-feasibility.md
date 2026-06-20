# WiFi 无线传输可行性

## 结论

**技术上可行**：控制层 TCP 6666 + 数据层 HTTP 80，社区已有列目录与下载实现。  
**官方不支持**电脑 WiFi 直连，需基于逆向协议维护，固件升级可能失效。

---

## 两层协议

| 层 | 机制 | 作用 |
|----|------|------|
| 控制 | TCP 6666，Protobuf，握手字符串 syNceNdinS | 列文件、参数、KeepAlive |
| 数据 | HTTP 80，支持 Range 206 | 实际下载 MP4 等文件 |

典型流程：

1. Mac 连接相机 WiFi AP（AP 模式下相机 IP 一般为 192.168.42.1）
2. TCP 6666 建立连接并完成 Sync
3. 发送 `GET_FILE_LIST`（命令码 13）获取路径列表
4. 对每条路径执行 HTTP GET 下载到本地

---

## 已有实现

| 项目 | 能力 | 链接 |
|------|------|------|
| insta360 (whitebox) | 列目录、并行 Range 下载、断点续传 | https://insta360.whitebox.aero |
| insta360-wifi-api | 早期 Python，列目录 | https://github.com/RigacciOrg/insta360-wifi-api |
| insta360ctl | GO 系列 BLE + WiFi 协议文档 | https://github.com/xaionaro-go/insta360ctl |

安装示例：

```bash
pip install insta360
```

---

## 风险

| 风险 | 等级 | 说明 |
|------|------|------|
| 固件升级破坏协议 | 高 | 需按机型/版本维护 |
| 新机型不兼容 | 高 | whitebox 主要测过 X3/X4 |
| 官方立场 | 中 | 电脑无线无技术支持 |
| 传输速度 | 低 | 通常低于 USB，够用即可 |

---

## Mac 特有问题

- **无法程序化切换 WiFi**（无公开 API），需用户手动连接相机热点
- AP 模式下 Mac 会断外网；可选 Station 模式让相机加入现有局域网（命令 112）
- 大文件需断点续传与 KeepAlive，避免相机休眠断连
