# GO 3S Quick File Transfer（官方流程）

> 本文档描述 **官方 App 流程**，供对照。本项目 Mac 工具不依赖此 UI，但协议层与 WiFi 传文件相关。

## 是否支持

GO 3S 支持 Quick File Transfer。需开启手机 **蓝牙、WiFi、定位（GPS）**。

---

## iOS

1. 在 Action Pod **相册**页选择素材  
2. 点击右下角 **Quick File Transfer**  
3. 相机通知上次连接的手机 → 手机确认  
4. App 自动连接，选中素材传到 Insta360 App  

无需事先打开 App（通知唤起）。

---

## Android

1. 先连接 Insta360 App（或先点 Quick Transfer 再连 App）  
2. Action Pod 相册选片 → Quick File Transfer  
3. 素材自动传到 App  

---

## 与本项目关系

| 官方 Quick Transfer | 本项目目标 |
|---------------------|------------|
| 手机 ↔ 相机 | **Mac ↔ 相机** |
| Action Pod 手动选片 | 目录增量导入，可选全部新文件 |
| Insta360 App 相册 | 本地文件夹 + 索引去重 |

底层仍可能共用：**BLE 唤起 WiFi + TCP 6666 + HTTP 80**。

---

## 参考

- [GO 3S Quick File Transfer FAQ](https://onlinemanual.insta360.com/go3s/en-us/faq/operationtutorials/quickfiletransfer)
- [GO Series Quick File Transfer](https://onlinemanual.insta360.com/goultra/en-us/operating_tutorials/file-transfer/quick-file-transfer)
