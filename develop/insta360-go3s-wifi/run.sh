#!/usr/bin/env bash
# Run CLI without pip reinstall (useful when Mac is on camera WiFi without internet).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export PYTHONPATH="${ROOT}/src:${PYTHONPATH:-}"
exec "${ROOT}/.venv/bin/python" -m insta360_go3s_wifi.cli "$@"
