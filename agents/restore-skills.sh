#!/usr/bin/env bash
set -Eeuo pipefail

MANIFEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skills-manifest.txt"

if ! command -v npx &>/dev/null; then
  echo "ERROR: npx not found. Install Node.js/fnm first." >&2
  exit 1
fi

echo "==> Restoring skills from manifest..."

while IFS= read -r line; do
  # 주석 및 빈 줄 건너뜀
  [[ -z "$line" || "$line" == \#* ]] && continue

  echo "    Installing: $line"
  npx skills add "$line" -g -y
done < "$MANIFEST"

echo "==> Skills restore complete."
