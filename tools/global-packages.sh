#!/usr/bin/env bash
set -Eeuo pipefail

MANIFEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/global-packages.txt"

if [[ ! -f "$MANIFEST" ]]; then
  echo "    global-packages.txt not found, skipping."
  exit 0
fi

echo "    Installing global npm packages..."
while IFS= read -r pkg || [[ -n "$pkg" ]]; do
  # 주석과 빈 줄 무시
  [[ "$pkg" =~ ^#.*$ || -z "$pkg" ]] && continue
  if npm list -g --depth=0 "$pkg" &>/dev/null; then
    echo "    already installed: $pkg"
  else
    echo "    installing: $pkg"
    npm install -g "$pkg"
  fi
done < "$MANIFEST"

echo "    Global packages done."
