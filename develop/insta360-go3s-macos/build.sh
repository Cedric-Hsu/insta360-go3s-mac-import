#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
swift build -c release
echo ""
echo "Run: .build/release/Insta360GO3SImport"
echo "Set INSTA360_CLI_ROOT if CLI is not at ../insta360-go3s-wifi"
