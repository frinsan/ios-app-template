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

# Optional second arg overrides the scratch root; default is <repo>/brand-builds/<brand>
DEFAULT_SCRATCH_ROOT="$(cd "$(dirname "$0")/../.." && pwd)/brand-builds"
SCRATCH_ROOT="${2:-${DEFAULT_SCRATCH_ROOT}}"
SCRATCH_DIR="${SCRATCH_ROOT}/$(basename "${BRAND_DIR}")"

TEMPLATE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVERLAY_DIR="${BRAND_DIR}/Overlay/TemplateApp"
OVERLAY_APP_DIR="${OVERLAY_DIR}/TemplateApp"

echo "Recreating scratch workspace at ${SCRATCH_DIR}"
rm -rf "${SCRATCH_DIR}"
mkdir -p "${SCRATCH_DIR}"

echo "Copying template from ${TEMPLATE_ROOT}..."
rsync -a --delete --exclude '.git' --exclude 'DerivedData' "${TEMPLATE_ROOT}/" "${SCRATCH_DIR}/"

if [[ -d "${OVERLAY_DIR}" ]]; then
  echo "Applying overlay from ${OVERLAY_DIR}..."
  # Do NOT delete at the root level so we keep template scripts and tooling.
  # Exclude TemplateApp.xcodeproj on the first pass; if a brand-specific project exists, we copy it explicitly below.
  rsync -a --exclude 'TemplateApp.xcodeproj' "${OVERLAY_DIR}/" "${SCRATCH_DIR}/"

  # If the brand provides its own TemplateApp.xcodeproj, prefer that over the base template project file
  # so that the scratch build reflects the brand's real app structure (Home flows, entry points, etc.).
  if [[ -f "${OVERLAY_DIR}/TemplateApp.xcodeproj/project.pbxproj" ]]; then
    echo "Overlay TemplateApp.xcodeproj detected; using brand project file instead of template default."
    rm -rf "${SCRATCH_DIR}/TemplateApp.xcodeproj"
    cp -R "${OVERLAY_DIR}/TemplateApp.xcodeproj" "${SCRATCH_DIR}/TemplateApp.xcodeproj"
  fi

  if [[ -d "${OVERLAY_APP_DIR}/Config" ]]; then
    rsync -a "${OVERLAY_APP_DIR}/Config/" "${SCRATCH_DIR}/TemplateApp/TemplateApp/Config/"
    cp "${OVERLAY_APP_DIR}/Config/presets_library.json" "${SCRATCH_DIR}/TemplateApp/TemplateApp/Config/" 2>/dev/null || true
    cp "${OVERLAY_APP_DIR}/Config/PresetLibraryLoader.swift" "${SCRATCH_DIR}/TemplateApp/TemplateApp/Config/" 2>/dev/null || true
  fi
else
  echo "No overlay found at ${OVERLAY_DIR}; skipping overlay step."
fi

echo "Applying manifest ${MANIFEST_PATH}..."
(cd "${SCRATCH_DIR}" && ./scripts/apply_manifest.sh "${MANIFEST_PATH}")

# Ensure overlay config files are present after manifest step.
PRESETS_SRC="${OVERLAY_APP_DIR}/Config/presets_library.json"
PRESETS_DST="${SCRATCH_DIR}/TemplateApp/TemplateApp/Config/presets_library.json"
if [[ -f "${PRESETS_SRC}" ]]; then
  cp "${PRESETS_SRC}" "${PRESETS_DST}"
else
  echo '{"presets":[]}' > "${PRESETS_DST}"
fi

LOADER_SRC="${OVERLAY_APP_DIR}/Config/PresetLibraryLoader.swift"
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
if [[ -d "${OVERLAY_APP_DIR}" ]]; then
  # Overlay app sources; do not --delete to avoid removing template-only files (e.g., Localization).
  rsync -a "${OVERLAY_APP_DIR}/" "${SCRATCH_DIR}/TemplateApp/TemplateApp/"
fi
# Force critical overlay files to override template defaults.
if [[ -f "${OVERLAY_APP_DIR}/Sidebar/RootContainerView.swift" ]]; then
  cp -f "${OVERLAY_APP_DIR}/Sidebar/RootContainerView.swift" "${SCRATCH_DIR}/TemplateApp/TemplateApp/Sidebar/RootContainerView.swift"
fi
if [[ -d "${OVERLAY_APP_DIR}/Home" ]]; then
  rm -rf "${SCRATCH_DIR}/TemplateApp/TemplateApp/Home"
  cp -a "${OVERLAY_APP_DIR}/Home" "${SCRATCH_DIR}/TemplateApp/TemplateApp/"
fi

# Re-apply bundle/version values explicitly on the scratch project file without replacing it.
if [[ -f "${SCRATCH_DIR}/TemplateApp.xcodeproj/project.pbxproj" ]]; then
  APP_ID=$(jq -r '.appId' "${MANIFEST_PATH}")
  MARKETING_VERSION=$(jq -r '.build.marketingVersion // empty' "${MANIFEST_PATH}")
  BUILD_NUMBER=$(jq -r '.build.buildNumber // empty' "${MANIFEST_PATH}")
  PROJ_PATH="${SCRATCH_DIR}/TemplateApp.xcodeproj/project.pbxproj"

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
