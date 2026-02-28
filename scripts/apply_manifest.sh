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
BASE_ENTITLEMENTS_FILE="$REPO_ROOT/TemplateApp/TemplateApp.entitlements"
CLOUD_ENTITLEMENTS_FILE="$REPO_ROOT/TemplateApp/TemplateAppCloud.entitlements"
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

if [[ ! -f "$BASE_ENTITLEMENTS_FILE" ]]; then
  echo "Entitlements file missing: $BASE_ENTITLEMENTS_FILE" >&2
  exit 1
fi

if [[ ! -f "$CLOUD_ENTITLEMENTS_FILE" ]]; then
  echo "Entitlements file missing: $CLOUD_ENTITLEMENTS_FILE" >&2
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

validate_optional_bool() {
  local expr=$1
  local name=$2
  if ! jq -e "${expr} | (. == null or type == \"boolean\")" "$SRC" >/dev/null; then
    echo "Manifest field must be boolean when present: ${name}" >&2
    exit 1
  fi
}

validate_optional_string() {
  local expr=$1
  local name=$2
  if ! jq -e "${expr} | (. == null or type == \"string\")" "$SRC" >/dev/null; then
    echo "Manifest field must be string when present: ${name}" >&2
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
validate_optional_bool '.features.settings' 'features.settings'
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
validate_optional_bool '.features.cloudSync' 'features.cloudSync'
validate_active_environment

if ! jq -e '.cloud.containerId == null' "$SRC" >/dev/null; then
  echo "Manifest field is not supported: cloud.containerId (Cloud sync uses default iCloud.<appId> container only)." >&2
  exit 1
fi

APP_ID=$(jq -r '.appId' "$SRC")
DISPLAY_NAME=$(jq -r '.displayName' "$SRC")
URL_SCHEME=$(jq -r '.auth.scheme' "$SRC")
MARKETING_VERSION=$(jq -r '.build.marketingVersion // empty' "$SRC")
BUILD_NUMBER=$(jq -r '.build.buildNumber // empty' "$SRC")
CLOUD_SYNC_ENABLED=$(jq -r '.features.cloudSync // false' "$SRC")
PUSH_ENABLED=$(jq -r '.features.push // false' "$SRC")

cp "$SRC" "$DEST"
echo "Manifest validated and copied from $SRC to $DEST"

update_build_setting() {
  local key=$1
  local value=$2
  perl -0pi -e 's#'"$key"' = [^;]+;#'"$key"' = '"$value"';#g' "$PROJECT_FILE"
}

update_build_setting "PRODUCT_BUNDLE_IDENTIFIER" "$APP_ID"
update_build_setting "INFOPLIST_KEY_CFBundleDisplayName" "\"$DISPLAY_NAME\""

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

get_background_modes_json() {
  plutil -extract UIBackgroundModes json -o - "$INFO_PLIST" 2>/dev/null || echo "[]"
}

set_background_modes_from_json_array() {
  local json_array=$1
  /usr/libexec/PlistBuddy -c "Delete :UIBackgroundModes" "$INFO_PLIST" >/dev/null 2>&1 || true
  local count
  count=$(echo "$json_array" | jq 'length')
  if [[ "$count" -eq 0 ]]; then
    return
  fi

  /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" "$INFO_PLIST" >/dev/null
  mapfile -t modes < <(echo "$json_array" | jq -r '.[]')
  for i in "${!modes[@]}"; do
    /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:${i} string ${modes[$i]}" "$INFO_PLIST" >/dev/null
  done
}

ensure_remote_notification_background_mode() {
  local modes_json
  modes_json=$(get_background_modes_json)
  if echo "$modes_json" | jq -e 'index("remote-notification") != null' >/dev/null; then
    return
  fi

  /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" "$INFO_PLIST" >/dev/null 2>&1 || true
  local index
  index=$(echo "$modes_json" | jq 'length')
  /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:${index} string remote-notification" "$INFO_PLIST" >/dev/null
}

remove_remote_notification_background_mode() {
  local modes_json
  modes_json=$(get_background_modes_json)
  if ! echo "$modes_json" | jq -e 'index("remote-notification") != null' >/dev/null; then
    return
  fi

  local next_modes
  next_modes=$(echo "$modes_json" | jq '[ .[] | select(. != "remote-notification") ]')
  set_background_modes_from_json_array "$next_modes"
}

if [[ "$CLOUD_SYNC_ENABLED" == "true" ]]; then
  ensure_remote_notification_background_mode
  echo "Enabled Info.plist background mode: remote-notification (CloudKit)."
elif [[ "$PUSH_ENABLED" != "true" ]]; then
  remove_remote_notification_background_mode
  echo "Removed Info.plist background mode: remote-notification."
fi

if [[ "$CLOUD_SYNC_ENABLED" == "true" ]]; then
  update_build_setting "CODE_SIGN_ENTITLEMENTS" "TemplateApp/TemplateAppCloud.entitlements"
  echo "Cloud sync enabled: using TemplateAppCloud.entitlements."
else
  update_build_setting "CODE_SIGN_ENTITLEMENTS" "TemplateApp/TemplateApp.entitlements"
  echo "Cloud sync disabled: using TemplateApp.entitlements."
fi

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
