# insta360-go3s-wifi

Unofficial **Insta360 GO 3S** WiFi import tool for macOS.

> Not affiliated with Insta360. Community protocol research may break on firmware updates.

## Quick start

```bash
cd develop/insta360-go3s-wifi
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
pip install -e ".[dev]"
```

Or without editable install while on camera WiFi (no internet):

```bash
./run.sh import ~/Movies/GO3S --new-only
```

## Before you import

1. Power on GO 3S (Action Pod helps avoid sleep).
2. On Action Pod: open **Album** → select any clip → tap **Quick File Transfer** (keep this screen active).
3. On Mac: connect to **`GO 3S xxxxxx.OSC`** WiFi (password often `88888888`).

### WiFi stability (screen can turn off)

Import automatically runs `caffeinate -i` on macOS: **system idle sleep is disabled**, but the **display may dim or turn off**. You do not need to keep the Mac screen on.

| Layer | What to do |
|-------|------------|
| **Mac** | Leave lid open or use clamshell + power; closing the lid usually sleeps WiFi regardless of our tool |
| **Mac** | System Settings → Battery → *Prevent automatic sleeping when display is off* (on power adapter) helps long imports |
| **Action Pod** | Keep **Quick File Transfer** active; this is the camera-side “session”, not your Mac screen |
| **Camera** | Keep GO 3S in the Action Pod so it does not auto power-off |
| **Opt out** | `INSTA360_KEEP_AWAKE=0 ./run.sh import ...` disables sleep prevention |

If WiFi drops mid-import, partial files resume on the next run (`--new-only`).

## Import new clips

```bash
insta360-go3s-wifi import ~/Movies/GO3S --new-only
```

Options:

| Flag | Description |
|------|-------------|
| `--new-only` | Skip clips already in the local index (default) |
| `--all` | Re-download every MP4 group on the camera |
| `--dry-run` | List pending files without downloading |
| `--open-finder` | Reveal destination folder when done |

Each MP4 is downloaded with its matching `.lrv` when present. Progress supports HTTP Range resume if a transfer is interrupted.

The local index lives at `{dest}/.insta360-go3s-wifi/index.json`.

## Other commands

| Command | Description |
|---------|-------------|
| `import` | Import MP4 (+ LRV) with deduplication |
| `status DEST` | Show indexed files for a destination |
| `ui` | JSON API for the macOS app (`ui connection`, `ui import`, …) |
| `list` | List remote paths via TCP 6666 |
| `verify` | Phase 1 connectivity + download smoke test |
| `diagnose` | Ping, TCP 6666/80, HTTP probes |
| `probe` | WiFi + ping + HTTP (no file list) |
| `raw-tcp` | Debug SYNC handshake bytes |

## Phase 1 validation

```bash
insta360-go3s-wifi verify
insta360-go3s-wifi verify --save-report ../../tests/GO3S_COMPAT.md
```

Record firmware and results in [tests/GO3S_COMPAT.md](../../tests/GO3S_COMPAT.md).

## Development

```bash
pytest
```

## License

MIT — see [LICENSE](./LICENSE).

## macOS app

SwiftUI desktop UI (iMovie-style layout): [../insta360-go3s-macos/README.md](../insta360-go3s-macos/README.md)
