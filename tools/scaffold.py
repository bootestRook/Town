#!/usr/bin/env python3
"""Stage, validate, archive, and verify the complete editable Godot project."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))
from tools import project as project_cli
from tools.package_profile import read_godot_config
from tools.source_archive import (
    MANIFEST_NAME, combined_fingerprint, excluded, fingerprint, inventory, manifest, stage_project,
)


def project_name(root: Path) -> str:
    name = read_godot_config(root / "project.godot")["application"]["config/name"]
    if not isinstance(name, str) or not name or any(char in name for char in '<>:"/\\|?*'):
        raise ValueError("project name must be a valid directory name")
    return name


def _zip_info(name: str, *, directory: bool = False) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, date_time=(2020, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.create_system = 0
    info.external_attr = 0x10 if directory else 0o100644 << 16
    return info


def write_archive(root: Path, output: Path, name: str) -> dict:
    contents = manifest(root, name)
    _, empty_directories = inventory(root)
    temporary = output.with_suffix(".zip.tmp")
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for index, entry in enumerate(contents["files"], 1):
                path = root / entry["path"]
                with path.open("rb") as source, archive.open(
                    _zip_info(f"{name}/{entry['path']}"), "w", force_zip64=entry["bytes"] >= zipfile.ZIP64_LIMIT
                ) as destination:
                    shutil.copyfileobj(source, destination, 1024 * 1024)
                if index % 500 == 0:
                    print(f"[OK] archived {index}/{contents['file_count']} files", flush=True)
            for path in empty_directories:
                archive.writestr(_zip_info(f"{name}/{path.relative_to(root).as_posix()}/", directory=True), b"")
            payload = (json.dumps(contents, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")
            archive.writestr(_zip_info(f"{name}/{MANIFEST_NAME}"), payload)
        temporary.replace(output)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    return contents


def check(output: Path, source_root: Path | None = None) -> bool:
    try:
        with zipfile.ZipFile(output) as archive:
            names = archive.namelist()
            if len(names) != len(set(names)):
                raise ValueError("duplicate ZIP entries")
            manifests = [name for name in names if name.count("/") == 1 and name.endswith(f"/{MANIFEST_NAME}")]
            if len(manifests) != 1:
                raise ValueError("expected exactly one root manifest")
            contents = json.loads(archive.read(manifests[0]).decode("utf-8"))
            prefix = contents["archive_root"] + "/"
            for name in names:
                path = PurePosixPath(name)
                if not name.startswith(prefix) or path.is_absolute() or ".." in path.parts or "\\" in name:
                    raise ValueError(f"unsafe archive path: {name}")
                relative = name[len(prefix):].rstrip("/")
                if relative != MANIFEST_NAME and excluded(relative, directory=name.endswith("/")):
                    raise ValueError(f"excluded path in archive: {relative}")
            entries = contents["files"]
            actual = sorted(name[len(prefix):] for name in names if not name.endswith("/") and name != manifests[0])
            if actual != sorted(entry["path"] for entry in entries):
                raise ValueError("manifest does not match ZIP contents")
            required = {"project.godot", "AI_AGENT_GUIDE.md", "README.md", "LICENSE", "THIRD_PARTY.md"}
            if not required.issubset(actual):
                raise ValueError("archive is missing required entry points")
            if contents["format_version"] != 1 or contents["file_count"] != len(entries):
                raise ValueError("invalid manifest version or file count")
            if contents["total_bytes"] != sum(entry["bytes"] for entry in entries):
                raise ValueError("invalid manifest byte count")
            if contents["combined_sha256"] != combined_fingerprint(entries):
                raise ValueError("combined manifest hash mismatch")
            for index, entry in enumerate(entries, 1):
                digest, count = hashlib.sha256(), 0
                with archive.open(prefix + entry["path"]) as stream:
                    for block in iter(lambda: stream.read(1024 * 1024), b""):
                        digest.update(block)
                        count += len(block)
                if count != entry["bytes"] or digest.hexdigest() != entry["sha256"]:
                    raise ValueError(f"entry checksum mismatch: {entry['path']}")
                if source_root is not None and fingerprint(source_root / entry["path"]) != (count, digest.hexdigest()):
                    raise ValueError(f"validated staging file changed: {entry['path']}")
                if index % 1000 == 0:
                    print(f"[OK] CRC/SHA-256 verified {index}/{len(entries)} files", flush=True)
        print(f"[OK] source archive check: files={len(entries)}, bytes={output.stat().st_size}", flush=True)
        return True
    except (OSError, UnicodeError, ValueError, zipfile.BadZipFile, KeyError) as exc:
        print(f"[FAIL] source archive: {exc}", flush=True)
        return False


def _run_stage(stage: Path, command: str, godot: str) -> None:
    result = subprocess.run(
        [sys.executable, "-u", "tools/project.py", command, "--godot", godot],
        cwd=stage, env=project_cli.process_environment(),
    )
    if result.returncode:
        raise ValueError(f"clean staging {command} failed with exit={result.returncode}")


def _import_stage(stage: Path, godot: str) -> None:
    result = subprocess.run(
        [godot, "--headless", "--language", "en", "--path", str(stage), "--editor", "--import", "--quit"],
        cwd=stage, env=project_cli.process_environment(), capture_output=True,
    )
    output = (result.stdout + result.stderr).decode("utf-8", errors="strict")
    log_path = stage / "validation" / "source_import.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(output.replace("\r\n", "\n"), encoding="utf-8", newline="\n")
    if result.returncode or "SCRIPT ERROR" in output or "ERROR:" in output:
        print("\n".join(output.splitlines()[-80:]), flush=True)
        raise ValueError("clean staging Godot import failed")
    print("[OK] clean Godot import: all source assets reimported", flush=True)


def build(output: Path, godot_hint: str = "") -> bool:
    if output.exists():
        raise ValueError(f"output already exists; choose a new filename: {output}")
    name = project_name(PROJECT_ROOT)
    godot = project_cli.find_godot(godot_hint)
    if not godot:
        raise ValueError("Godot not found; set GODOT_BIN or pass --godot")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".source-archive-", dir=output.parent) as temporary:
        temporary_root = Path(temporary).resolve()
        if not temporary_root.is_relative_to(output.parent.resolve()) or temporary_root == output.parent.resolve():
            raise ValueError("temporary cleanup target must remain under the output directory")
        stage = temporary_root / name
        count = stage_project(PROJECT_ROOT, stage)
        print(f"[OK] isolated clean staging: files={count}", flush=True)
        for command in ("data", "assets"):
            _run_stage(stage, command, godot)
        _import_stage(stage, godot)
        for command in ("graphs", "release", "check"):
            _run_stage(stage, command, godot)
        contents = write_archive(stage, output, name)
        if not check(output, stage):
            output.unlink(missing_ok=True)
            return False
        print(f"[OK] complete editable project: {output}", flush=True)
        print(f"[OK] uncompressed source bytes={contents['total_bytes']}", flush=True)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "check"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--godot", default="")
    args = parser.parse_args()
    try:
        output = (args.output or PROJECT_ROOT / "build" / f"{project_name(PROJECT_ROOT)}-工程源码.zip").resolve()
        if output.is_relative_to(PROJECT_ROOT) and not output.is_relative_to(PROJECT_ROOT / "build"):
            raise ValueError("output inside the checkout must stay under build/")
        return 0 if (build(output, args.godot) if args.command == "build" else check(output)) else 1
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"[FAIL] source archive: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
