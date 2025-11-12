#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-manifest-json>" >&2
  exit 1
fi

MANIFEST_SOURCE=$1
MANIFEST_DEST="TemplateApp/TemplateApp/Config/app.json"

if [[ ! -f "$MANIFEST_SOURCE" ]]; then
  echo "Manifest file not found: $MANIFEST_SOURCE" >&2
  exit 1
fi

cp "$MANIFEST_SOURCE" "$MANIFEST_DEST"
echo "Applied manifest from $MANIFEST_SOURCE to $MANIFEST_DEST"
