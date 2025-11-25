#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/app-<brand> [scratch-dir]" >&2
  exit 1
fi

BRAND_DIR="$(cd "$1" && pwd)"
MANIFEST_PATH="${BRAND_DIR}/app.json"

if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "Manifest not found at ${MANIFEST_PATH}" >&2
  exit 1
fi

# Optional second arg overrides the scratch root; default is ~/Documents/brand-builds/<brand>
SCRATCH_ROOT="${2:-${HOME}/Documents/brand-builds}"
SCRATCH_DIR="${SCRATCH_ROOT}/$(basename "${BRAND_DIR}")"

TEMPLATE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVERLAY_DIR="${BRAND_DIR}/Overlay/TemplateApp"

echo "Recreating scratch workspace at ${SCRATCH_DIR}"
rm -rf "${SCRATCH_DIR}"
mkdir -p "${SCRATCH_DIR}"

echo "Copying template from ${TEMPLATE_ROOT}..."
rsync -a --delete --exclude '.git' --exclude 'DerivedData' "${TEMPLATE_ROOT}/" "${SCRATCH_DIR}/"

if [[ -d "${OVERLAY_DIR}" ]]; then
  echo "Applying overlay from ${OVERLAY_DIR}..."
  rsync -a "${OVERLAY_DIR}/" "${SCRATCH_DIR}/TemplateApp/"
else
  echo "No overlay found at ${OVERLAY_DIR}; skipping overlay step."
fi

echo "Applying manifest ${MANIFEST_PATH}..."
(cd "${SCRATCH_DIR}" && ./scripts/apply_manifest.sh "${MANIFEST_PATH}")

cat <<'EOF'
----------
Scratch build ready.
- Open the project from the scratch copy:
    open <scratch_dir>/TemplateApp/TemplateApp.xcodeproj
- Build/run in Xcode; this does NOT touch your main checkout.
Re-run this script after changing the brand manifest or overlay files.
----------
EOF
echo "Scratch directory: ${SCRATCH_DIR}"
