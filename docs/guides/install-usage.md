# 安装与使用

> **重要：** 连相机 WiFi 时 Mac 无法上网，请勿在相机热点下执行 `pip install`。  
> 先在普通 WiFi 下 `pip install -e ".[dev]"`，再切到 `GO 3S xxx.OSC` 测试。

## Phase 1（当前）：实机验证

### 前置条件

- macOS（Apple Silicon 或 Intel）
- Insta360 GO 3S
- Python 3.9+

### 安装

```bash
cd develop/insta360-go3s-wifi
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
pip install -e ".[dev]"
```

### 验证

1. Mac 连接 `GO 3S *.OSC` WiFi（见 [go3s-wifi-setup.md](./go3s-wifi-setup.md)）
2. 运行：

```bash
insta360-go3s-wifi probe
insta360-go3s-wifi verify --save-report ../../tests/GO3S_COMPAT.md
```

3. 在 [tests/GO3S_COMPAT.md](../../tests/GO3S_COMPAT.md) 补充固件版本与结论

## Phase 2（规划）

```bash
insta360-go3s-wifi import --dest ~/Movies/GO3S --new-only
```
