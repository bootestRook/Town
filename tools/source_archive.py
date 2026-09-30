"""Portable source selection, documentation links, and streamed fingerprints."""
from __future__ import annotations

import hashlib
import os
import re
import shutil
from pathlib import Path, PurePosixPath

MANIFEST_NAME = "scaffold-manifest.json"
LOCAL_SOURCE_DOCUMENT = "docs/research/SOURCE_REFERENCE.md"
EXCLUDED_DIRECTORIES = {
    ".git", ".godot", ".import", "__pycache__", ".pytest_cache",
    "node_modules", "build", "dist", "reports", "validation",
}
EXCLUDED_SUFFIXES = {
    ".pyc", ".pyo", ".log", ".tmp", ".temp", ".bak", ".blend1", ".blend2",
    ".exe", ".pck", ".zip", ".apk", ".aab",
}
EXCLUDED_FILES = {MANIFEST_NAME, LOCAL_SOURCE_DOCUMENT, "Thumbs.db", ".DS_Store"}
MARKDOWN_LINK = re.compile(r"(!?)\[([^\]\n]+)\]\(([^)\n]+)\)")


def excluded(relative: str, *, directory: bool = False) -> bool:
    path = PurePosixPath(relative)
    return (
        relative in EXCLUDED_FILES
        or path.name in {"Thumbs.db", ".DS_Store"}
        or any(part in EXCLUDED_DIRECTORIES for part in path.parts)
        or relative == ".impeccable/review"
        or relative.startswith(".impeccable/review/")
        or (not directory and path.suffix.lower() in EXCLUDED_SUFFIXES)
    )


def inventory(root: Path) -> tuple[list[Path], list[Path]]:
    files, empty_directories = [], []
    for current, dirs, names in os.walk(root):
        parent = Path(current)
        dirs[:] = sorted(name for name in dirs if not excluded(
            (parent / name).relative_to(root).as_posix(), directory=True
        ))
        selected = [parent / name for name in sorted(names) if not excluded(
            (parent / name).relative_to(root).as_posix()
        )]
        for path in [*(parent / name for name in dirs), *selected]:
            if path.is_symlink():
                raise ValueError(f"source archive cannot contain a symbolic link: {path}")
        files.extend(selected)
        if not dirs and not selected and parent != root:
            empty_directories.append(parent)
    return sorted(files), sorted(empty_directories)


def portable_markdown(text: str, relative: str, source_root: Path) -> str:
    document = source_root / relative

    def replace(match: re.Match) -> str:
        target = match[3].strip().strip("<>").split("#", 1)[0]
        if not target or re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
            return match[0]
        resolved = (document.parent / target).resolve()
        if not resolved.is_relative_to(source_root):
            return match[0]
        local = resolved.relative_to(source_root).as_posix()
        if local == LOCAL_SOURCE_DOCUMENT:
            provenance = Path(os.path.relpath(source_root / "THIRD_PARTY.md", document.parent)).as_posix()
            return f"本机来源索引（未随包提供；[资源来源登记]({provenance})）"
        if excluded(local, directory=resolved.is_dir()):
            return f"{match[2]}（本机验收记录，未随工程归档）"
        return match[0]

    return MARKDOWN_LINK.sub(replace, text)


def stage_project(source_root: Path, stage_root: Path) -> int:
    files, empty_directories = inventory(source_root)
    for path in files:
        relative = path.relative_to(source_root).as_posix()
        destination = stage_root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if path.suffix.lower() == ".md":
            text = portable_markdown(path.read_text(encoding="utf-8"), relative, source_root)
            destination.write_text(text, encoding="utf-8", newline="\n")
        else:
            shutil.copy2(path, destination)
    for path in empty_directories:
        (stage_root / path.relative_to(source_root)).mkdir(parents=True, exist_ok=True)
    return len(files)


def fingerprint(path: Path) -> tuple[int, str]:
    digest, count = hashlib.sha256(), 0
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
            count += len(block)
    return count, digest.hexdigest()


def combined_fingerprint(entries: list[dict]) -> str:
    combined = hashlib.sha256()
    for entry in entries:
        combined.update(entry["path"].encode("utf-8"))
        combined.update(b"\0")
        combined.update(entry["sha256"].encode("ascii"))
        combined.update(b"\n")
    return combined.hexdigest()


def manifest(root: Path, project_name: str) -> dict:
    files, _ = inventory(root)
    entries = []
    for path in files:
        count, digest = fingerprint(path)
        entries.append({"path": path.relative_to(root).as_posix(), "bytes": count, "sha256": digest})
    return {
        "format_version": 1,
        "archive_root": project_name,
        "project": project_name,
        "file_count": len(entries),
        "total_bytes": sum(entry["bytes"] for entry in entries),
        "combined_sha256": combined_fingerprint(entries),
        "files": entries,
    }
