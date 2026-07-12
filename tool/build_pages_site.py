#!/usr/bin/env python3
"""Validate and stage all committed mini-program artifacts for GitHub Pages."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
from typing import Any


SEMVER_PATTERN = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")


class PagesBuildError(Exception):
    pass


def read_json(path: Path, label: str) -> dict[str, Any]:
    if not path.is_file():
        raise PagesBuildError(f"{label} is missing: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise PagesBuildError(f"{label} is not valid UTF-8 JSON: {path}: {error}") from error
    if not isinstance(value, dict):
        raise PagesBuildError(f"{label} must be a JSON object: {path}")
    return value


def require_text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise PagesBuildError(f"{label} must be a non-empty string")
    return value.strip()


def require_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise PagesBuildError(f"{label} must be an integer")
    return value


def validate_relative_path(value: Any, label: str) -> str:
    raw_path = require_text(value, label)
    if "\\" in raw_path or raw_path.startswith("/") or raw_path.endswith("/"):
        raise PagesBuildError(f"{label} is not a safe portable path: {raw_path}")
    path = PurePosixPath(raw_path)
    if path.is_absolute() or any(part in ("", ".", "..") for part in path.parts):
        raise PagesBuildError(f"{label} is not a safe portable path: {raw_path}")
    if path.as_posix() != raw_path:
        raise PagesBuildError(f"{label} is not normalized: {raw_path}")
    return raw_path


def reject_links(root: Path) -> None:
    if root.is_symlink():
        raise PagesBuildError(f"Symbolic links are not allowed: {root}")
    for current_root, directory_names, file_names in os.walk(root, followlinks=False):
        current = Path(current_root)
        for name in (*directory_names, *file_names):
            candidate = current / name
            if candidate.is_symlink():
                raise PagesBuildError(f"Symbolic links are not allowed: {candidate}")


def validate_version(app_id: str, version: str, version_root: Path) -> dict[str, Any]:
    if not SEMVER_PATTERN.fullmatch(version):
        raise PagesBuildError(f"Invalid semantic version for {app_id}: {version}")
    if not version_root.is_dir():
        raise PagesBuildError(f"Version directory is missing: {version_root}")
    reject_links(version_root)

    manifest = read_json(version_root / "manifest.json", "Version manifest")
    release = read_json(version_root / "release.json", "Release metadata")
    checksums = read_json(version_root / "checksums.json", "Checksum metadata")

    if manifest.get("id") != app_id or manifest.get("version") != version:
        raise PagesBuildError(
            f"Manifest identity does not match {app_id}/{version}: {version_root / 'manifest.json'}"
        )
    if manifest.get("artifactLayoutVersion") != 1:
        raise PagesBuildError(f"Unsupported artifact layout for {app_id}/{version}")
    if release.get("appId") != app_id or release.get("version") != version:
        raise PagesBuildError(f"Release identity does not match {app_id}/{version}")
    expected_release_values = {
        "manifest": "manifest.json",
        "checksums": "checksums.json",
        "screensPath": "screens/",
        "assetsPath": "assets/",
    }
    for key, expected in expected_release_values.items():
        if release.get(key) != expected:
            raise PagesBuildError(
                f"Release field {key} must be {expected!r} for {app_id}/{version}"
            )

    screens_root = version_root / "screens"
    assets_root = version_root / "assets"
    if not screens_root.is_dir() or not assets_root.is_dir():
        raise PagesBuildError(f"Screens or assets directory is missing for {app_id}/{version}")
    entry = require_text(manifest.get("entry"), f"{app_id}/{version} manifest entry")
    entry_path = screens_root / f"{entry}.json"
    if not entry_path.is_file():
        raise PagesBuildError(f"Entry screen is missing: {entry_path}")

    screen_schema_version = require_int(
        manifest.get("screenSchemaVersion"),
        f"{app_id}/{version} screenSchemaVersion",
    )
    screen_files = sorted(screens_root.glob("*.json"))
    if not screen_files:
        raise PagesBuildError(f"No screens were found for {app_id}/{version}")
    for screen_file in screen_files:
        screen = read_json(screen_file, "Screen")
        if screen.get("schemaVersion") != screen_schema_version:
            raise PagesBuildError(
                f"Screen schema does not match the manifest: {screen_file}"
            )
        if not isinstance(screen.get("root"), dict):
            raise PagesBuildError(f"Screen root must be a JSON object: {screen_file}")

    if checksums.get("algorithm") != "sha256":
        raise PagesBuildError(f"Unsupported checksum algorithm for {app_id}/{version}")
    records = checksums.get("files")
    if not isinstance(records, list) or not records:
        raise PagesBuildError(f"Checksum records are missing for {app_id}/{version}")

    expected_files: dict[str, tuple[int, str]] = {}
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise PagesBuildError(f"Checksum record {index} is not an object")
        relative_path = validate_relative_path(
            record.get("path"), f"Checksum path {index}"
        )
        if relative_path == "checksums.json" or relative_path in expected_files:
            raise PagesBuildError(f"Duplicate or recursive checksum path: {relative_path}")
        byte_count = require_int(record.get("bytes"), f"{relative_path} byte count")
        digest = require_text(record.get("sha256"), f"{relative_path} sha256")
        if byte_count < 0 or not SHA256_PATTERN.fullmatch(digest):
            raise PagesBuildError(f"Invalid checksum metadata for {relative_path}")
        expected_files[relative_path] = (byte_count, digest)

    actual_files = {
        path.relative_to(version_root).as_posix(): path
        for path in version_root.rglob("*")
        if path.is_file() and path.name != "checksums.json"
    }
    if set(actual_files) != set(expected_files):
        missing = sorted(set(expected_files) - set(actual_files))
        unexpected = sorted(set(actual_files) - set(expected_files))
        raise PagesBuildError(
            f"Checksum file set mismatch for {app_id}/{version}; "
            f"missing={missing}, unexpected={unexpected}"
        )

    for relative_path, path in actual_files.items():
        contents = path.read_bytes()
        expected_size, expected_digest = expected_files[relative_path]
        actual_digest = hashlib.sha256(contents).hexdigest()
        if len(contents) != expected_size or actual_digest != expected_digest:
            raise PagesBuildError(f"Checksum mismatch: {path}")
    return manifest


def validate_app(app_root: Path) -> tuple[str, list[str]]:
    reject_links(app_root)
    app_id = app_root.name
    catalog = read_json(app_root / "catalog.json", "Artifact catalog")
    latest = read_json(app_root / "latest.json", "Latest manifest")
    if catalog.get("appId") != app_id or latest.get("id") != app_id:
        raise PagesBuildError(f"Artifact app identity does not match directory: {app_root}")
    if catalog.get("artifactLayoutVersion") != 1:
        raise PagesBuildError(f"Unsupported catalog layout for {app_id}")

    raw_versions = catalog.get("versions")
    if not isinstance(raw_versions, list) or not raw_versions:
        raise PagesBuildError(f"Catalog versions are missing for {app_id}")
    versions = [require_text(value, f"{app_id} catalog version") for value in raw_versions]
    if len(set(versions)) != len(versions):
        raise PagesBuildError(f"Catalog contains duplicate versions for {app_id}")

    version_directories = sorted(
        child.name
        for child in app_root.iterdir()
        if child.is_dir() and not child.name.startswith(".")
    )
    if set(version_directories) != set(versions):
        raise PagesBuildError(
            f"Catalog versions do not match version directories for {app_id}"
        )

    latest_version = require_text(catalog.get("latestVersion"), f"{app_id} latestVersion")
    if latest_version not in versions or latest.get("version") != latest_version:
        raise PagesBuildError(f"Latest metadata is inconsistent for {app_id}")

    latest_manifest: dict[str, Any] | None = None
    for version in versions:
        manifest = validate_version(app_id, version, app_root / version)
        if version == latest_version:
            latest_manifest = manifest
    if latest_manifest != latest:
        raise PagesBuildError(f"latest.json does not match {app_id}/{latest_version}/manifest.json")
    return app_id, versions


def resolve_output(repo_root: Path, raw_output: str) -> Path:
    output = Path(raw_output)
    if not output.is_absolute():
        output = repo_root / output
    output = output.resolve()
    mini_apps_root = (repo_root / "mini-apps").resolve()
    if output == repo_root or not output.is_relative_to(repo_root):
        raise PagesBuildError(f"Output must stay inside the repository: {output}")
    if output == mini_apps_root or output.is_relative_to(mini_apps_root):
        raise PagesBuildError(f"Output must not overwrite mini-program sources: {output}")
    return output


def build_site(repo_root: Path, output: Path) -> list[tuple[str, list[str], Path]]:
    mini_apps_root = repo_root / "mini-apps"
    if not mini_apps_root.is_dir():
        raise PagesBuildError(f"mini-apps directory is missing: {mini_apps_root}")

    discovered: list[tuple[str, list[str], Path]] = []
    app_ids: set[str] = set()
    for project_root in sorted(path for path in mini_apps_root.iterdir() if path.is_dir()):
        artifacts_root = project_root / "artifacts"
        if not artifacts_root.is_dir():
            continue
        reject_links(artifacts_root)
        for app_root in sorted(path for path in artifacts_root.iterdir() if path.is_dir()):
            app_id, versions = validate_app(app_root)
            if app_id in app_ids:
                raise PagesBuildError(f"Duplicate artifact appId discovered: {app_id}")
            app_ids.add(app_id)
            discovered.append((app_id, versions, app_root))
    if not discovered:
        raise PagesBuildError("No mini-program artifact bundles were discovered")

    staging = output.with_name(f".{output.name}.staging-{os.getpid()}")
    if staging.exists():
        shutil.rmtree(staging)
    try:
        artifacts_output = staging / "artifacts"
        artifacts_output.mkdir(parents=True)
        (staging / ".nojekyll").write_text("", encoding="utf-8")
        for app_id, _, app_root in discovered:
            shutil.copytree(app_root, artifacts_output / app_id)
        if output.exists():
            shutil.rmtree(output)
        staging.rename(output)
    except Exception:
        if staging.exists():
            shutil.rmtree(staging)
        raise
    return discovered


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate and stage mini-program artifacts for GitHub Pages."
    )
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default="_site")
    args = parser.parse_args()

    try:
        repo_root = Path(args.repo_root).resolve()
        output = resolve_output(repo_root, args.output)
        discovered = build_site(repo_root, output)
    except (OSError, PagesBuildError) as error:
        print(f"pages_build_failed: {error}", file=sys.stderr)
        return 1

    print(f"Staged {len(discovered)} mini-program(s) at {output}")
    for app_id, versions, source in discovered:
        print(f"- {app_id}: {', '.join(versions)} ({source.relative_to(repo_root)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
