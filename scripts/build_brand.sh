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
  # Do NOT delete at the root level so we keep template scripts and tooling.
  rsync -a "${OVERLAY_DIR}/" "${SCRATCH_DIR}/"
  if [[ -f "${OVERLAY_DIR}/TemplateApp.xcodeproj/project.pbxproj" ]]; then
    echo "Using overlay project file from ${OVERLAY_DIR}/TemplateApp.xcodeproj"
    cp "${OVERLAY_DIR}/TemplateApp.xcodeproj/project.pbxproj" "${SCRATCH_DIR}/TemplateApp.xcodeproj/project.pbxproj"
  fi
  if [[ -d "${OVERLAY_DIR}/TemplateApp/TemplateApp/Config" ]]; then
    rsync -a --delete "${OVERLAY_DIR}/TemplateApp/TemplateApp/Config/" "${SCRATCH_DIR}/TemplateApp/TemplateApp/Config/"
    cp "${OVERLAY_DIR}/TemplateApp/TemplateApp/Config/presets_library.json" "${SCRATCH_DIR}/TemplateApp/TemplateApp/Config/" 2>/dev/null || true
    cp "${OVERLAY_DIR}/TemplateApp/TemplateApp/Config/PresetLibraryLoader.swift" "${SCRATCH_DIR}/TemplateApp/TemplateApp/Config/" 2>/dev/null || true
  fi
else
  echo "No overlay found at ${OVERLAY_DIR}; skipping overlay step."
fi

echo "Applying manifest ${MANIFEST_PATH}..."
(cd "${SCRATCH_DIR}" && ./scripts/apply_manifest.sh "${MANIFEST_PATH}")

# Ensure overlay config files are present after manifest step.
PRESETS_SRC="${OVERLAY_DIR}/TemplateApp/TemplateApp/Config/presets_library.json"
PRESETS_DST="${SCRATCH_DIR}/TemplateApp/TemplateApp/Config/presets_library.json"
if [[ -f "${PRESETS_SRC}" ]]; then
  cp "${PRESETS_SRC}" "${PRESETS_DST}"
else
  echo '{"presets":[]}' > "${PRESETS_DST}"
fi

LOADER_SRC="${OVERLAY_DIR}/TemplateApp/TemplateApp/Config/PresetLibraryLoader.swift"
LOADER_DST="${SCRATCH_DIR}/TemplateApp/TemplateApp/Config/PresetLibraryLoader.swift"
if [[ -f "${LOADER_SRC}" ]]; then
  cp "${LOADER_SRC}" "${LOADER_DST}"
else
  cat > "${LOADER_DST}" <<'SWIFT'
import Foundation

struct PresetLibrary: Decodable {
    let presets: [PhotoPreset]
}

enum PresetLibraryLoader {
    static func loadPresets() -> [PhotoPreset] { [] }
}
SWIFT
fi

# Ensure overlay app sources (Home/Components/Config) are present after manifest step.
if [[ -d "${OVERLAY_DIR}/TemplateApp/TemplateApp" ]]; then
  rsync -a --delete "${OVERLAY_DIR}/TemplateApp/TemplateApp/" "${SCRATCH_DIR}/TemplateApp/TemplateApp/"
fi
# Force critical overlay files to override template defaults.
if [[ -f "${OVERLAY_DIR}/TemplateApp/TemplateApp/Sidebar/RootContainerView.swift" ]]; then
  cp -f "${OVERLAY_DIR}/TemplateApp/TemplateApp/Sidebar/RootContainerView.swift" "${SCRATCH_DIR}/TemplateApp/TemplateApp/Sidebar/RootContainerView.swift"
fi
if [[ -d "${OVERLAY_DIR}/TemplateApp/TemplateApp/Home" ]]; then
  rm -rf "${SCRATCH_DIR}/TemplateApp/TemplateApp/Home"
  cp -a "${OVERLAY_DIR}/TemplateApp/TemplateApp/Home" "${SCRATCH_DIR}/TemplateApp/TemplateApp/"
fi

# Re-apply overlay project file after manifest tweaks and set bundle/version values explicitly.
if [[ -f "${OVERLAY_DIR}/TemplateApp.xcodeproj/project.pbxproj" ]]; then
  APP_ID=$(jq -r '.appId' "${MANIFEST_PATH}")
  MARKETING_VERSION=$(jq -r '.build.marketingVersion // empty' "${MANIFEST_PATH}")
  BUILD_NUMBER=$(jq -r '.build.buildNumber // empty' "${MANIFEST_PATH}")
  PROJ_PATH="${SCRATCH_DIR}/TemplateApp.xcodeproj/project.pbxproj"

  cp "${OVERLAY_DIR}/TemplateApp.xcodeproj/project.pbxproj" "${PROJ_PATH}"
  perl -0pi -e 's/PRODUCT_BUNDLE_IDENTIFIER = [^;]+;/PRODUCT_BUNDLE_IDENTIFIER = '"${APP_ID}"';/g' "${PROJ_PATH}"
  if [[ -n "${MARKETING_VERSION}" ]]; then
    perl -0pi -e 's/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = '"${MARKETING_VERSION}"';/g' "${PROJ_PATH}"
  fi
  if [[ -n "${BUILD_NUMBER}" ]]; then
    perl -0pi -e 's/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = '"${BUILD_NUMBER}"';/g' "${PROJ_PATH}"
  fi
fi

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
