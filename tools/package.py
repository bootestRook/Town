#!/usr/bin/env python3
"""Validate an approved display contract, then export a WebApp or Windows package."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))
from tools import project as project_cli
from tools import release_manifest as release_manifest_tool
from tools.package_profile import MAX_WEB_ARCHIVE_BYTES, load_profiles, validate_profile


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()



def write_artifact_manifest(
    profile_name: str,
    stage: str,
    summary: dict[str, Any],
    source_fingerprint: str,
    godot_version: str,
    root: Path = PROJECT_ROOT,
) -> Path:
    output = root / str(summary["output"])
    artifact_root = output.parent
    manifest_path = artifact_root / "package-manifest.json"
    files = []
    for path in sorted(artifact_root.rglob("*")):
        if path.is_file() and path != manifest_path:
            files.append(
                {
                    "path": path.relative_to(artifact_root).as_posix(),
                    "bytes": path.stat().st_size,
                    "sha256": _sha256(path),
                }
            )
    if not output.is_file():
        raise FileNotFoundError(f"expected export output was not created: {summary['output']}")
    manifest = {
        "format_version": 2,
        "profile": profile_name,
        "stage": stage,
        "design_resolution": summary["design_resolution"],
        "godot_version": godot_version,
        "fresh_engine_cache": True,
        "source_combined_sha256": source_fingerprint,
        "output": summary["output"],
        "files": files,
    }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    return manifest_path



def write_web_archive(summary: dict[str, Any], root: Path = PROJECT_ROOT) -> tuple[Path, int, str]:
    output = root / str(summary["output"])
    artifact_root = output.parent
    archive_path = root / str(summary["archive"])
    try:
        html = output.read_text(encoding="utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise ValueError(f"index.html is not valid UTF-8 at byte {exc.start}") from exc
    if not re.search(r"<meta\s+[^>]*charset\s*=\s*['\"]?utf-8", html, re.IGNORECASE):
        raise ValueError("index.html must declare UTF-8 with a meta charset")
    if archive_path.exists():
        archive_path.unlink()
    with zipfile.ZipFile(
        archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for path in sorted(artifact_root.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(artifact_root).as_posix())
    with zipfile.ZipFile(archive_path) as archive:
        if "index.html" not in archive.namelist():
            archive_path.unlink()
            raise ValueError("Web archive must contain index.html at its root")
    archive_bytes = archive_path.stat().st_size
    max_bytes = int(summary["max_archive_bytes"])
    if archive_bytes > max_bytes:
        archive_path.unlink()
        raise ValueError(f"Web archive is {archive_bytes} bytes; limit is {max_bytes} bytes")
    return archive_path, archive_bytes, _sha256(archive_path)



def check(profile_name: str, require_adaptation_review: bool = True) -> tuple[bool, dict[str, Any]]:
    try:
        issues, summary = validate_profile(
            profile_name, require_adaptation_review=require_adaptation_review
        )
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as exc:
        issues, summary = [str(exc)], {}
    if issues:
        print(f"[FAIL] package profile {profile_name}: {len(issues)} issue(s)")
        for issue in issues:
            print(f"  {issue}")
        print("[NEXT] update package_profiles.json after completing the required review in docs/PACKAGING.md")
        return False, summary
    matrix = ", ".join(f"{width}x{height}" for width, height in summary["test_resolutions"])
    print(
        f"[OK] package profile {profile_name}: design={summary['design_resolution'][0]}x"
        f"{summary['design_resolution'][1]}, matrix={matrix}, output={summary['output']}"
    )
    return True, summary



def _clean_artifact_root(output: Path) -> None:
    artifact_root = output.parent.resolve()
    build_root = (PROJECT_ROOT / "build").resolve()
    if artifact_root == build_root or not artifact_root.is_relative_to(build_root):
        raise ValueError("artifact directory must be a child of build/")
    if artifact_root.exists():
        shutil.rmtree(artifact_root)
    artifact_root.mkdir(parents=True)



def _remove_web_archive(summary: dict[str, Any]) -> None:
    archive_path = (PROJECT_ROOT / str(summary["archive"])).resolve()
    build_root = (PROJECT_ROOT / "build").resolve()
    if archive_path.parent == build_root and archive_path.suffix.lower() == ".zip":
        archive_path.unlink(missing_ok=True)
        return
    raise ValueError("Web archive must be a .zip directly under build/")



def clean_engine_caches(root: Path = PROJECT_ROOT) -> None:
    root = root.resolve()
    for name in (".godot", ".import"):
        cache = (root / name).resolve()
        if cache.parent != root or cache.name != name:
            raise ValueError(f"unsafe engine cache path: {cache}")
        if cache.exists():
            shutil.rmtree(cache)



def _godot_version(godot: str) -> str:
    result = subprocess.run(
        [godot, "--version"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        env=project_cli.process_environment(),
    )
    output = (result.stdout + result.stderr).decode("utf-8", errors="strict").strip()
    if result.returncode != 0 or not output:
        raise ValueError("cannot read Godot version")
    return output.splitlines()[0]



def prepare_fresh_inputs(godot: str) -> tuple[bool, str, str]:
    try:
        clean_engine_caches()
        godot_version = _godot_version(godot)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"[FAIL] fresh build preparation: {exc}")
        return False, "", ""
    steps = (
        project_cli.generate_data,
        project_cli.generate_assets,
        lambda: project_cli.run_tool("release_manifest.py", "build"),
        lambda: project_cli.checks(godot, include_smoke=True),
    )
    if not all(step() for step in steps):
        return False, "", ""
    try:
        fingerprint = str(release_manifest_tool.build_manifest()["combined_sha256"])
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"[FAIL] source fingerprint: {exc}")
        return False, "", ""
    print(f"[OK] fresh source fingerprint: {fingerprint}")
    return True, fingerprint, godot_version



def export(profile_name: str, godot_hint: str, stage: str) -> bool:
    valid, summary = check(profile_name, require_adaptation_review=stage == "release")
    if not valid:
        return False
    godot = project_cli.find_godot(godot_hint)
    if not godot:
        print("[FAIL] Godot 4 not found; set GODOT_BIN or use --godot")
        return False
    prepared, source_fingerprint, godot_version = prepare_fresh_inputs(godot)
    if not prepared:
        return False
    profile = load_profiles()["profiles"][profile_name]
    output = PROJECT_ROOT / summary["output"]
    try:
        if profile_name == "webapp":
            _remove_web_archive(summary)
        _clean_artifact_root(output)
    except (OSError, ValueError) as exc:
        print(f"[FAIL] prepare artifact directory: {exc}")
        return False
    command = [
        godot,
        "--headless",
        "--language",
        "en",
        "--path",
        str(PROJECT_ROOT),
        "--export-release",
        profile["preset"],
        str(output),
    ]
    if not project_cli.run_command(command, f"export {stage} {profile_name}", scan_output=True):
        return False
    try:
        current_fingerprint = str(release_manifest_tool.build_manifest()["combined_sha256"])
        if current_fingerprint != source_fingerprint:
            raise ValueError("source files changed while packaging; export is invalid")
        manifest_path = write_artifact_manifest(
            profile_name,
            stage,
            summary,
            source_fingerprint,
            godot_version,
        )
        if profile_name == "webapp":
            archive_path, archive_bytes, archive_sha256 = write_web_archive(summary)
    except (OSError, UnicodeError, ValueError, zipfile.BadZipFile) as exc:
        print(f"[FAIL] package artifact: {exc}")
        return False
    print(f"[OK] artifact manifest: {manifest_path.relative_to(PROJECT_ROOT).as_posix()}")
    if profile_name == "webapp":
        print(
            f"[OK] Web archive: {archive_path.relative_to(PROJECT_ROOT).as_posix()}, "
            f"bytes={archive_bytes}, sha256={archive_sha256}"
        )
    return True



def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("candidate", "check", "export"))
    parser.add_argument("profile", choices=("webapp", "exe"))
    parser.add_argument("--godot", default="", help="path to a Godot 4 executable")
    args = parser.parse_args(argv)
    if args.command == "check":
        ok = check(args.profile)[0]
    else:
        stage = "candidate" if args.command == "candidate" else "release"
        ok = export(args.profile, args.godot, stage)
    return 0 if ok else 1



if __name__ == "__main__":
    raise SystemExit(main())
