#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <manifest-path>" >&2
  exit 1
fi
SRC=$1
DEST="TemplateApp/TemplateApp/Config/app.json"
if [[ ! -f "$SRC" ]]; then
  echo "Manifest not found: $SRC" >&2
  exit 1
fi
cp "$SRC" "$DEST"
echo "Manifest copied from $SRC to $DEST"
