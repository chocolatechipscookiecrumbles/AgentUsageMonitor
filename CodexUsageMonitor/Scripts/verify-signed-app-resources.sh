#!/bin/zsh
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
app="${1:-$root/.build/CodexUsageMonitor.app}"

asset_catalog="$app/Contents/Resources/Assets.car"

if [[ ! -f "$asset_catalog" ]]; then
  echo "missing signed-app asset catalog: $asset_catalog" >&2
  exit 1
fi

asset_metadata="$(xcrun assetutil --info "$asset_catalog")"
for asset_name in Codex Claude Copilot; do
  if [[ "$asset_metadata" != *"\"Name\" : \"$asset_name\""* ]]; then
    echo "missing signed-app agent asset: $asset_name" >&2
    exit 1
  fi
done

echo "signed-app asset catalog present"
