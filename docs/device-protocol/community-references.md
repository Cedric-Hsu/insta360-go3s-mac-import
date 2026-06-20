# 社区参考索引

| 项目 | 语言 | 主要用途 | 链接 |
|------|------|----------|------|
| insta360 (whitebox) | Python | 列目录、HTTP 下载、预览流 | https://insta360.whitebox.aero |
| insta360ctl | Go | GO 3S BLE/WiFi 协议、Station 模式 CLI | https://github.com/xaionaro-go/insta360ctl |
| insta360-wifi-api | Python | 早期 WiFi 控制、GET_FILE_LIST | https://github.com/RigacciOrg/insta360-wifi-api |
| insta360-go-firmware-tool | Python | GO 2/3/3S telnet、WiFi AP 信息 | https://github.com/enekochan/insta360-go-firmware-tool |
| Insta360_OSC | 文档 | OSC HTTP fileUrl 示例（老机型） | https://github.com/Insta360Develop/Insta360_OSC |
| rigacci 逆向笔记 | Wiki | protobuf 提取方法 | https://www.rigacci.org/wiki/doku.php/doc/appunti/hardware/insta360_one_rs_wifi_reverse_engineering |

## 本项目依赖策略

1. **Phase 1**：优先 `pip install insta360`，在 GO 3S 实机验证  
2. 若 GO 3S 不兼容：fork whitebox 或参考 insta360-wifi-api 最小实现  
3. **BLE 层**：参考 insta360ctl，不在 Phase 1 实现  
4. **不在仓库内**分发 `libOne.so` 或 APK  

## protobuf 定义来源说明

社区通常从 Insta360 Android App 的 `libOne.so` 用 pbtk 等工具提取 `.proto`，再 `protoc` 生成代码。  
过程见 rigacci wiki 与 insta360-wifi-api 的 utils 目录说明。
