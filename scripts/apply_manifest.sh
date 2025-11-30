#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <manifest-path>" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to validate manifests. Install jq and retry." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MANIFEST_INPUT=$1
if [[ "$MANIFEST_INPUT" = /* ]]; then
  SRC="$MANIFEST_INPUT"
else
  MANIFEST_DIR="$(cd "$(dirname "$MANIFEST_INPUT")" && pwd)"
  SRC="$MANIFEST_DIR/$(basename "$MANIFEST_INPUT")"
fi

DEST="$REPO_ROOT/TemplateApp/TemplateApp/Config/app.json"
PROJECT_FILE="$REPO_ROOT/TemplateApp.xcodeproj/project.pbxproj"
INFO_PLIST="$REPO_ROOT/TemplateApp/TemplateApp/Info.plist"
TEMPLATE_ASSETS_DIR="$REPO_ROOT/TemplateApp/TemplateApp/Assets.xcassets"
BRAND_ASSETS_DIR="$(cd "$(dirname "$SRC")" && pwd)/Assets"

if [[ ! -f "$SRC" ]]; then
  echo "Manifest not found: $SRC" >&2
  exit 1
fi

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "Xcode project file missing: $PROJECT_FILE" >&2
  exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Info.plist missing: $INFO_PLIST" >&2
  exit 1
fi

# Helper functions to validate manifest fields using jq selectors.
validate_string() {
  local expr=$1
  local name=$2
  if ! jq -e "${expr} | select(type == \"string\" and length > 0)" "$SRC" >/dev/null; then
    echo "Manifest missing required string: ${name}" >&2
    exit 1
  fi
}

validate_bool() {
  local expr=$1
  local name=$2
  if ! jq -e "${expr} | type == \"boolean\"" "$SRC" >/dev/null; then
    echo "Manifest missing required boolean: ${name}" >&2
    exit 1
  fi
}

validate_active_environment() {
  if ! jq -e '.activeEnvironment | select(. == "staging" or . == "prod")' "$SRC" >/dev/null; then
    echo 'Manifest activeEnvironment must be "staging" or "prod".' >&2
    exit 1
  fi
}

# Ensure manifest is valid JSON before performing granular checks.
jq empty "$SRC" >/dev/null

validate_string '.appId' 'appId'
validate_string '.displayName' 'displayName'
validate_string '.bundleIdSuffix' 'bundleIdSuffix'
validate_string '.theme.primary' 'theme.primary'
validate_string '.theme.accent' 'theme.accent'
validate_string '.theme.appearance' 'theme.appearance'
validate_bool '.features.login' 'features.login'
validate_bool '.features.feedback' 'features.feedback'
validate_bool '.features.share' 'features.share'
validate_bool '.features.push' 'features.push'
validate_string '.apiBase.staging' 'apiBase.staging'
validate_string '.apiBase.prod' 'apiBase.prod'
validate_string '.auth.cognitoClientId' 'auth.cognitoClientId'
validate_string '.auth.scheme' 'auth.scheme'
validate_string '.auth.region' 'auth.region'
validate_string '.auth.hostedUIDomain' 'auth.hostedUIDomain'
validate_string '.legal.privacyUrl' 'legal.privacyUrl'
validate_string '.legal.termsUrl' 'legal.termsUrl'
validate_active_environment

APP_ID=$(jq -r '.appId' "$SRC")
DISPLAY_NAME=$(jq -r '.displayName' "$SRC")
URL_SCHEME=$(jq -r '.auth.scheme' "$SRC")
MARKETING_VERSION=$(jq -r '.build.marketingVersion // empty' "$SRC")
BUILD_NUMBER=$(jq -r '.build.buildNumber // empty' "$SRC")

cp "$SRC" "$DEST"
echo "Manifest validated and copied from $SRC to $DEST"

update_build_setting() {
  local key=$1
  local value=$2
  perl -0pi -e 's/'"$key"' = [^;]+;/'"$key"' = '"$value"';/g' "$PROJECT_FILE"
}

update_build_setting "PRODUCT_BUNDLE_IDENTIFIER" "$APP_ID"

if [[ -n "$MARKETING_VERSION" ]]; then
  update_build_setting "MARKETING_VERSION" "$MARKETING_VERSION"
fi

if [[ -n "$BUILD_NUMBER" ]]; then
  update_build_setting "CURRENT_PROJECT_VERSION" "$BUILD_NUMBER"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleName $DISPLAY_NAME" "$INFO_PLIST" >/dev/null
/usr/libexec/PlistBuddy -c "Delete :CFBundleDisplayName" "$INFO_PLIST" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $DISPLAY_NAME" "$INFO_PLIST" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLName $APP_ID" "$INFO_PLIST" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $URL_SCHEME" "$INFO_PLIST" >/dev/null

if [[ -d "$BRAND_ASSETS_DIR" ]]; then
  find "$BRAND_ASSETS_DIR" -mindepth 1 -maxdepth 1 -print0 | while IFS= read -r -d '' asset; do
    name="$(basename "$asset")"
    dest="$TEMPLATE_ASSETS_DIR/$name"
    rm -rf "$dest"
    cp -R "$asset" "$dest"
  done
  echo "Assets copied from $BRAND_ASSETS_DIR to $TEMPLATE_ASSETS_DIR"
else
  echo "No brand assets directory found at $BRAND_ASSETS_DIR; skipping asset overrides."
fi

echo "Bundle identifier, Info.plist values, and assets updated for $DISPLAY_NAME"
