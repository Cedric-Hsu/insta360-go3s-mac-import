# 技术选型

## 总览

| 层 | 选型 | 理由 |
|----|------|------|
| 协议核心 | Python 3.10+ | whitebox `insta360` 包成熟；迭代快 |
| CLI | `typer` 或 `argparse` | 轻量、易测 |
| 索引 | JSON 或 SQLite | 记录 path、size、mtime、sha256 可选 |
| Mac UI（后期） | Tauri 2 **或** SwiftUI + 子进程 | Tauri 跨平台；SwiftUI 更原生 |
| 测试 | pytest | 索引与路径逻辑单测 |

## 代码位置

```
develop/insta360-go3s-wifi/
├── pyproject.toml
├── LICENSE
├── README.md
├── src/insta360_go3s_wifi/
│   ├── client.py       # 封装 TCP + HTTP
│   ├── downloader.py   # 成组 MP4+LRV、断点续传
│   ├── index.py        # 本地去重
│   └── cli.py
└── tests/
```

## 依赖策略

1. **首选**：`pip install insta360` 作为依赖  
2. GO 3S 不兼容时：fork 必要模块进 `src/`，保持 MIT  
3. **不**在仓库提交 Insta360 二进制  

## Mac 限制

- 无法代码自动连接 WiFi → CLI/App 引导用户手动连接  
- 读取当前 SSID：`system_profiler SPAirPortDataType` 或 Network.framework（UI 阶段）  

## 文件成组规则

以 MP4 为主键；若列表中存在 `{stem}.lrv`，同一批次下载。

```python
# 伪代码
for mp4 in filter(is_mp4, new_files):
    download(mp4)
    lrv = sibling_lrv(mp4)
    if lrv in remote_files:
        download(lrv)
```

## 开源元数据

- 仓库名建议：`insta360-go3s-wifi`  
- License：MIT  
- `.gitignore`：`.venv/`、`__pycache__/`、本地下载目录、`.env`  
