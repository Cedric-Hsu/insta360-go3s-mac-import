# Insta360 GO 3S Mac WiFi Import

**Unofficial** macOS app + CLI to **wirelessly import videos from Insta360 GO 3S to your Mac** — without copying files through the phone app one by one.

> 非官方工具 · 在 Mac 上通过 Wi‑Fi 从 Insta360 GO 3S **无线导入视频**到本地，支持增量导入、断点续传与已导入/未导入筛选。  
> 与 Insta360 公司无关。Insta360、GO 3S、Action Pod、Quick File Transfer 等名称归各自权利人所有。

---

## Download (macOS app)

| Release | File | Requirements |
|---------|------|----------------|
| **[Latest Release →](https://github.com/Cedric-Hsu/insta360-go3s-mac-import/releases/latest)** | `Insta360 GO 3S Import.dmg` | macOS 13+, Apple Silicon or Intel, **Xcode Command Line Tools** |

1. Open the DMG and drag **Insta360 GO 3S Import** to Applications.
2. First launch: if macOS blocks the app, **right‑click → Open** (ad‑hoc signed, not App Store).
3. Connect GO 3S Wi‑Fi, enable **Quick File Transfer** on Action Pod (phone Insta360 app must pair first).

---

## What problem does this solve?

If you searched for any of these, this project is for you:

| Search intent (EN) | 中文搜索意图 |
|--------------------|-------------|
| Insta360 GO 3S transfer to Mac wirelessly | GO 3S 无线传 Mac / 导入 Mac |
| GO 3S Quick File Transfer Mac computer | Quick File Transfer 电脑 / Mac 直连 |
| Insta360 GO 3S WiFi download without phone | 不用手机 从相机 WiFi 下载 |
| GO 3S export videos to Mac without USB cable | 不用数据线 导出视频 |
| Insta360 GO 3S Mac app alternative | Mac 端导入工具 / 第三方 |
| GO 3S xxxxxx.OSC WiFi password Mac | GO 3S WiFi 密码 Mac 连接 |
| Insta360 Action Pod file transfer Mac | Action Pod 传文件到 Mac |
| Bulk import GO 3S MP4 to Mac | 批量导入 / 增量同步 |

Official Insta360 docs focus on **phone app → Mac via Finder/iPhone**, or **USB Drive Mode**. This tool adds a **Mac-native Wi‑Fi path** when Quick File Transfer is active on the camera.

---

## Features

- **macOS desktop app** (SwiftUI) — browse camera clips, filter **All / Imported / Not imported**, thumbnails, preview, menu bar shortcut
- **Python CLI** — scriptable import, diagnostics, JSON API for automation
- **Incremental import** — local index; skip already-downloaded files
- **Resume interrupted downloads** — HTTP range resume
- **Bilingual UI** — 简体中文 / English (Settings → Language)
- **Connection diagnostics** — Wi‑Fi, ping, TCP 6666, HTTP checks with guided setup

---

## How to use (GO 3S)

1. Power on GO 3S in **Action Pod**.
2. Pair with **Insta360 app** on your phone (Bluetooth; enable Wi‑Fi / Location as prompted).
3. On Mac: join Wi‑Fi **`GO 3S xxxxxx.OSC`**. Password is on Action Pod: **Settings → Wi‑Fi info** (not always `88888888`).
4. On Action Pod: **Album → any clip → Quick File Transfer** (keep that screen).
5. Open **Insta360 GO 3S Import** → **Check Connection** → **Import New**.

Default save folder: `~/Movies/GO3S`

Detailed guides: [docs/guides/go3s-wifi-setup.md](docs/guides/go3s-wifi-setup.md) · [troubleshooting](docs/guides/go3s-troubleshooting.md)

---

## Testing scope & community feedback

**I only own Insta360 GO 3S.** Everything in this repo was developed and tested on **my MacBook + GO 3S** only.

| Status | Device |
|--------|--------|
| ✅ Tested by author | Insta360 **GO 3S** + macOS |
| ❓ Not tested | GO 3, GO Ultra, X3, X4, One RS, etc. |
| ❓ Not tested | Other Mac models / macOS versions beyond author's setup |

If you have another **Insta360 camera** (non‑GO‑3S) or a different Mac, you are welcome to try the [CLI](develop/insta360-go3s-wifi/README.md) or the app and **open an [Issue](https://github.com/Cedric-Hsu/insta360-go3s-mac-import/issues)** with your model, macOS version, and logs. Community reports help everyone.

Firmware updates may break Wi‑Fi protocols at any time — **back up your footage** before relying on this tool.

---

## If this works for you — please share

This is a personal open-source side project. If it saves you time:

- ⭐ **Star** this repo on GitHub  
- 🔗 Share the [Releases page](https://github.com/Cedric-Hsu/insta360-go3s-mac-import/releases) with other GO 3S Mac users  
- 🐛 Report bugs or compatibility via Issues  

Thank you for helping more people find a Mac Wi‑Fi import option.

---

## Project structure

```
insta360-go3s-mac-import/
├── develop/
│   ├── insta360-go3s-wifi/     # Python CLI (TCP 6666 + HTTP 80)
│   └── insta360-go3s-macos/    # SwiftUI macOS app
├── docs/                       # Research, protocol notes, guides
└── tests/                      # Real-device test checklist
```

| Component | Docs |
|-----------|------|
| CLI | [develop/insta360-go3s-wifi/README.md](develop/insta360-go3s-wifi/README.md) |
| macOS app | [develop/insta360-go3s-macos/README.md](develop/insta360-go3s-macos/README.md) |
| Protocol & research | [docs/device-protocol/](docs/device-protocol/) |

---

## Build from source

### CLI

```bash
cd develop/insta360-go3s-wifi
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
pytest
insta360-go3s-wifi ui connection   # after connecting GO 3S Wi-Fi
```

### macOS app

```bash
cd develop/insta360-go3s-macos
./build.sh && ./run.sh
# Package DMG:
./package.sh --dmg
```

---

## Acknowledgments — projects we built on

This tool would not exist without community reverse-engineering and open libraries:

| Project | Author / org | Role in this repo |
|---------|--------------|-------------------|
| [**insta360**](https://gitlab.com/avilabss/insta360) (PyPI) | avilabss | RTMP/protobuf camera protocol — core dependency |
| [**insta360ctl**](https://github.com/xaionaro-go/insta360ctl) | xaionaro-go | GO series BLE/Wi‑Fi protocol reference |
| [**insta360-wifi-api**](https://github.com/RigacciOrg/insta360-wifi-api) | RigacciOrg | Early Wi‑Fi / GET_FILE_LIST research |
| [**insta360-go-firmware-tool**](https://github.com/enekochan/insta360-go-firmware-tool) | enekochan | GO 2/3/3S telnet & Wi‑Fi AP notes |
| [**Insta360_OSC**](https://github.com/Insta360Develop/Insta360_OSC) | Insta360Develop | OSC HTTP API documentation |
| [**insta360** (Whitebox)](https://gitlab.com/whitebox-aero/insta360) | Whitebox Aero | Protocol docs at [insta360.whitebox.aero](https://insta360.whitebox.aero) |
| [Rigacci Wi‑Fi reverse-engineering notes](https://www.rigacci.org/wiki/doku.php/doc/appunti/hardware/insta360_one_rs_wifi_reverse_engineering) | RigacciOrg | Protobuf extraction methodology |

Python stack also uses [Typer](https://github.com/tiangolo/typer), [Rich](https://github.com/Textualize/rich), [pytest](https://github.com/pytest-dev/pytest), and others — see `pyproject.toml`.

**Thank you** to all maintainers and researchers above.

---

## Legal & trademark

- **Unofficial.** Not affiliated with, endorsed by, or sponsored by Insta360 or Arash Vision.
- Insta360®, GO 3S™, and related marks are trademarks of their respective owners.
- Uses community protocol research; may stop working after camera firmware or app updates.
- **If you believe this project infringes your rights**, please contact: **[xunyu2017@gmail.com](mailto:xunyu2017@gmail.com)** — I will review and respond promptly.

---

## License

MIT — see [LICENSE](LICENSE).

The bundled [`insta360`](https://pypi.org/project/insta360/) Python package is **GPL-3.0-or-later** (avilabss). If you redistribute combined binaries, comply with both MIT (this repo) and GPL (insta360) terms.

---

## Contact

- Issues & feature requests: [GitHub Issues](https://github.com/Cedric-Hsu/insta360-go3s-mac-import/issues)
- Email: [xunyu2017@gmail.com](mailto:xunyu2017@gmail.com)
