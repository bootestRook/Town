"""Schema, CSV tables, references, and validation orchestration."""
from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any
from tools.content_values import ContentValidationError, ValidationIssue, SUPPORTED_TYPES, _issue, _normalize_value
from tools.content_constraints import _validate_constraints

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCHEMA = PROJECT_ROOT / "data" / "schema" / "data_schema.json"
DEFAULT_SOURCE = PROJECT_ROOT / "data" / "source"


def _read_utf8(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="strict")



def _load_schema(schema_path: Path) -> dict[str, Any]:
    try:
        schema = json.loads(_read_utf8(schema_path))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read schema {schema_path}: {exc}") from exc

    if not isinstance(schema, dict) or not isinstance(schema.get("tables"), dict):
        raise ValueError("schema must contain a 'tables' object")
    if not isinstance(schema.get("schema_version"), int):
        raise ValueError("schema_version must be an integer")

    for table_name, table_schema in schema["tables"].items():
        fields = table_schema.get("fields", [])
        if not isinstance(fields, list) or not fields:
            raise ValueError(f"table {table_name} must declare at least one field")
        names = [field.get("name") for field in fields]
        if any(not isinstance(name, str) or not name for name in names):
            raise ValueError(f"table {table_name} has a field without a name")
        if len(names) != len(set(names)):
            raise ValueError(f"table {table_name} has duplicate field names")
        unsupported = [
            field.get("type") for field in fields if field.get("type") not in SUPPORTED_TYPES
        ]
        if unsupported:
            raise ValueError(f"table {table_name} uses unsupported types: {unsupported}")
        primary_key = table_schema.get("primary_key", [])
        if not primary_key or any(key not in names for key in primary_key):
            raise ValueError(f"table {table_name} has an invalid primary_key")
        if not isinstance(table_schema.get("source"), str):
            raise ValueError(f"table {table_name} must declare a source CSV")
    return schema



def _load_table(
    table_name: str,
    table_schema: dict[str, Any],
    source_dir: Path,
    issues: list[ValidationIssue],
) -> tuple[list[dict[str, Any]], list[int]]:
    source_name = table_schema["source"]
    source_path = source_dir / source_name
    field_schemas = table_schema["fields"]
    expected_fields = [field["name"] for field in field_schemas]
    rows: list[dict[str, Any]] = []
    row_numbers: list[int] = []

    if not source_path.is_file():
        _issue(
            issues,
            source_name,
            table_name,
            0,
            "<file>",
            "",
            "existing UTF-8 CSV file",
            "missing",
            f"create content/source/{source_name}",
        )
        return rows, row_numbers

    try:
        handle = source_path.open("r", encoding="utf-8", errors="strict", newline="")
    except (OSError, UnicodeError) as exc:
        _issue(
            issues,
            source_name,
            table_name,
            0,
            "<file>",
            "",
            "strict UTF-8 CSV",
            str(exc),
            "save the source as UTF-8 without BOM",
        )
        return rows, row_numbers

    with handle:
        reader = csv.DictReader(handle)
        actual_fields = reader.fieldnames or []
        if actual_fields != expected_fields:
            _issue(
                issues,
                source_name,
                table_name,
                1,
                "<header>",
                "",
                ",".join(expected_fields),
                ",".join(actual_fields),
                "make the header exactly match schema field order",
            )
            return rows, row_numbers

        primary_key = table_schema["primary_key"]
        seen_keys: dict[tuple[Any, ...], int] = {}
        for row_number, raw_row in enumerate(reader, start=2):
            provisional_id = str(raw_row.get(primary_key[0], "")).strip()
            context = {
                "source": source_name,
                "table": table_name,
                "row": row_number,
                "content_id": provisional_id,
            }
            normalized = {
                field["name"]: _normalize_value(
                    str(raw_row.get(field["name"], "")), field, context, issues
                )
                for field in field_schemas
            }
            key = tuple(normalized.get(field) for field in primary_key)
            if key in seen_keys:
                _issue(
                    issues,
                    source_name,
                    table_name,
                    row_number,
                    "+".join(primary_key),
                    provisional_id,
                    "unique primary key",
                    key,
                    f"change the key; first declared on row {seen_keys[key]}",
                )
            else:
                seen_keys[key] = row_number
            rows.append(normalized)
            row_numbers.append(row_number)

    rows_with_lines = list(zip(rows, row_numbers, strict=True))
    rows_with_lines.sort(key=lambda pair: tuple(pair[0].get(key) for key in table_schema["primary_key"]))
    return [pair[0] for pair in rows_with_lines], [pair[1] for pair in rows_with_lines]



def _validate_references(
    schema: dict[str, Any],
    tables: dict[str, list[dict[str, Any]]],
    row_lines: dict[str, list[int]],
    issues: list[ValidationIssue],
) -> None:
    lookup: dict[tuple[str, str], set[Any]] = {}
    for table_name, table_schema in schema["tables"].items():
        for field in table_schema["fields"]:
            lookup[(table_name, field["name"])] = {
                row[field["name"]] for row in tables[table_name]
            }

    for table_name, table_schema in schema["tables"].items():
        primary_field = table_schema["primary_key"][0]
        source_name = table_schema["source"]
        for index, row in enumerate(tables[table_name]):
            content_id = str(row.get(primary_field, ""))
            for field in table_schema["fields"]:
                if field["type"] != "ref" or not row.get(field["name"]):
                    continue
                target = (field["table"], field["field"])
                if target not in lookup:
                    raise ValueError(f"schema reference targets unknown field: {target}")
                if row[field["name"]] not in lookup[target]:
                    _issue(
                        issues,
                        source_name,
                        table_name,
                        row_lines[table_name][index],
                        field["name"],
                        content_id,
                        f"existing {field['table']}.{field['field']} reference",
                        row[field["name"]],
                        "add the referenced row or correct the ID",
                    )



def load_and_validate(
    schema_path: Path = DEFAULT_SCHEMA,
    source_dir: Path = DEFAULT_SOURCE,
) -> tuple[dict[str, Any], dict[str, list[dict[str, Any]]]]:
    schema = _load_schema(schema_path)
    issues: list[ValidationIssue] = []
    tables: dict[str, list[dict[str, Any]]] = {}
    row_lines: dict[str, list[int]] = {}

    for table_name in sorted(schema["tables"]):
        rows, lines = _load_table(
            table_name, schema["tables"][table_name], source_dir, issues
        )
        tables[table_name] = rows
        row_lines[table_name] = lines

    _validate_references(schema, tables, row_lines, issues)
    _validate_constraints(schema, tables, row_lines, issues)
    if issues:
        raise ContentValidationError(issues)
    return schema, tables
