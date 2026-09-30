#!/usr/bin/env python3
"""Validate classified design-data tables and build deterministic runtime JSON."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))
from tools.content_values import ContentValidationError
from tools.content_tables import DEFAULT_SCHEMA, DEFAULT_SOURCE, load_and_validate

DEFAULT_OUTPUT = PROJECT_ROOT / "data" / "generated"
CATALOG_NAME = "data_catalog.json"
MANIFEST_NAME = "data_manifest.json"


def _json_bytes(value: Any) -> bytes:
    text = json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    return text.encode("utf-8", errors="strict")



def _source_fingerprints(schema_path: Path, source_dir: Path, schema: dict[str, Any]) -> list[dict[str, Any]]:
    paths = [schema_path]
    paths.extend(
        source_dir / schema["tables"][name]["source"] for name in sorted(schema["tables"])
    )
    fingerprints = []
    for path in paths:
        data = path.read_bytes()
        relative = path.relative_to(PROJECT_ROOT).as_posix() if path.is_relative_to(PROJECT_ROOT) else path.name
        fingerprints.append(
            {"path": relative, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        )
    return fingerprints



def build_outputs(
    schema_path: Path = DEFAULT_SCHEMA,
    source_dir: Path = DEFAULT_SOURCE,
) -> tuple[dict[str, bytes], dict[str, int]]:
    schema, tables = load_and_validate(schema_path, source_dir)
    catalog = {"schema_version": schema["schema_version"], "tables": tables}
    catalog_bytes = _json_bytes(catalog)
    source_files = _source_fingerprints(schema_path, source_dir, schema)
    combined = hashlib.sha256()
    for item in source_files:
        combined.update(item["path"].encode("utf-8"))
        combined.update(b"\0")
        combined.update(item["sha256"].encode("ascii"))
        combined.update(b"\n")
    manifest = {
        "format_version": 1,
        "schema_version": schema["schema_version"],
        "generator": "tools/content_pipeline.py",
        "catalog_sha256": hashlib.sha256(catalog_bytes).hexdigest(),
        "combined_source_sha256": combined.hexdigest(),
        "source_files": source_files,
    }
    counts = {table: len(rows) for table, rows in tables.items()}
    return {CATALOG_NAME: catalog_bytes, MANIFEST_NAME: _json_bytes(manifest)}, counts



def _write_outputs(output_dir: Path, outputs: dict[str, bytes]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for name, data in outputs.items():
        (output_dir / name).write_bytes(data)



def _check_outputs(output_dir: Path, outputs: dict[str, bytes]) -> list[str]:
    stale = []
    for name, expected in outputs.items():
        path = output_dir / name
        if not path.is_file() or path.read_bytes() != expected:
            stale.append(name)
    return stale



def _print_success(command: str, counts: dict[str, int], json_mode: bool) -> None:
    payload = {"status": "ok", "command": command, "table_rows": counts}
    if json_mode:
        print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
    else:
        summary = ", ".join(f"{name}={count}" for name, count in sorted(counts.items()))
        print(f"[OK] data {command}: {summary}")



def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "check", "validate"))
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)

    try:
        outputs, counts = build_outputs(args.schema, args.source)
        if args.command == "build":
            _write_outputs(args.output, outputs)
        elif args.command == "check":
            stale = _check_outputs(args.output, outputs)
            if stale:
                message = f"generated data is stale or missing: {', '.join(stale)}"
                if args.json:
                    print(json.dumps({"status": "error", "message": message}, ensure_ascii=False))
                else:
                    print(f"[FAIL] {message}\n[NEXT] python tools/project.py data")
                return 1
        _print_success(args.command, counts, args.json)
        return 0
    except ContentValidationError as exc:
        if args.json:
            print(
                json.dumps(
                    {"status": "error", "issues": [issue.as_dict() for issue in exc.issues]},
                    ensure_ascii=False,
                    sort_keys=True,
                )
            )
        else:
            print(f"[FAIL] {len(exc.issues)} data validation issue(s)")
            for issue in exc.issues:
                print(f"  {issue}")
        return 1
    except (OSError, UnicodeError, ValueError) as exc:
        payload = {"status": "error", "message": str(exc)}
        print(json.dumps(payload, ensure_ascii=False) if args.json else f"[FAIL] {exc}")
        return 1



if __name__ == "__main__":
    raise SystemExit(main())
