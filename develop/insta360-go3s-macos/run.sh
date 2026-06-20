#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export INSTA360_CLI_ROOT="${INSTA360_CLI_ROOT:-$ROOT/../insta360-go3s-wifi}"
exec "$ROOT/.build/release/Insta360GO3SImport"
