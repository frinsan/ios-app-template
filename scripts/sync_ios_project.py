#!/usr/bin/env python3
import json
import plistlib
import re
import sys
from pathlib import Path


def update_project_bundle_id(project_path: Path, bundle_id: str) -> None:
    """Replace all PRODUCT_BUNDLE_IDENTIFIER settings with bundle_id."""
    text = project_path.read_text()
    pattern = r"(PRODUCT_BUNDLE_IDENTIFIER = )[^;]+;"
    new_text, count = re.subn(pattern, r"\1" + bundle_id + ";", text)
    if count == 0:
        raise RuntimeError("Failed to update PRODUCT_BUNDLE_IDENTIFIER in project file.")
    project_path.write_text(new_text)


def update_info_plist(info_plist_path: Path, display_name: str, bundle_id: str, url_scheme: str) -> None:
    with info_plist_path.open("rb") as f:
        plist = plistlib.load(f)

    plist["CFBundleDisplayName"] = display_name
    plist["CFBundleName"] = display_name

    url_types = plist.setdefault("CFBundleURLTypes", [])
    if url_types:
        url_dict = url_types[0]
    else:
        url_dict = {}
        url_types.append(url_dict)
    url_dict["CFBundleURLName"] = bundle_id
    url_dict["CFBundleURLSchemes"] = [url_scheme]

    with info_plist_path.open("wb") as f:
        plistlib.dump(plist, f)


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: sync_ios_project.py <manifest-path>", file=sys.stderr)
        sys.exit(1)

    manifest_path = Path(sys.argv[1]).resolve()
    repo_root = Path(__file__).resolve().parents[1]
    project_path = repo_root / "TemplateApp.xcodeproj" / "project.pbxproj"
    info_plist_path = repo_root / "TemplateApp" / "TemplateApp" / "Info.plist"

    with manifest_path.open() as f:
        manifest = json.load(f)

    bundle_id = manifest["appId"]
    display_name = manifest["displayName"]
    url_scheme = manifest["auth"]["scheme"]

    update_project_bundle_id(project_path, bundle_id)
    update_info_plist(info_plist_path, display_name, bundle_id, url_scheme)


if __name__ == "__main__":
    main()
