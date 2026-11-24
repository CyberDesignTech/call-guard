#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "$0")/.."
exec flutter build apk --release --target-platform android-arm64
