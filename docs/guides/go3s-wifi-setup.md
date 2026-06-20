# GO 3S WiFi 连接指南

> 占位文档。实机验证后补充截图与故障排除。

## 1. 开启相机

- GO 3S 开机；建议放入 Action Pod 避免误触关机  
- 确认相机 WiFi 已开启（官方 App 连接过一次后通常可用）

## 2. Mac 连接 WiFi

1. 打开 **系统设置 → WiFi**  
2. 选择 **`GO 3S XXXXXX.OSC`**  
3. 输入密码（默认常为 `88888888`，或在相机 **Settings → WiFi Settings** 查看）

## 3. 验证连通性

```bash
ping -c 3 192.168.42.1
```

## 4. 常见问题

| 现象 | 建议 |
|------|------|
| 找不到 SSID | 重启相机；用官方 App 连一次唤醒 WiFi |
| 密码错误 | 相机设置或 App 中查看/重置 WiFi 密码 |
| ping 不通 | 确认 Mac 未仍连着其他 WiFi；关闭 VPN |
| 连接后断连 | 相机休眠；保持 Phase 1 脚本 KeepAlive 或轻触 Pod |

## 5. 注意

连接相机 WiFi 期间，Mac **通常无法上网**（AP 模式）。如需同时上网，见 Phase 3 Station 模式方案。
