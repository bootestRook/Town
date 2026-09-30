"""Cross-table design constraints evaluated after CSV normalization."""
from __future__ import annotations

import math
from typing import Any
from tools.content_values import ValidationIssue, _issue


def _validate_constraints(
    schema: dict[str, Any],
    tables: dict[str, list[dict[str, Any]]],
    row_lines: dict[str, list[int]],
    issues: list[ValidationIssue],
) -> None:
    for constraint in schema.get("constraints", []):
        constraint_type = constraint.get("type")
        if constraint_type == "required_child":
            parent_table = constraint["parent_table"]
            parent_field = constraint["parent_field"]
            child_table = constraint["child_table"]
            child_field = constraint["child_field"]
            child_values = {row[child_field] for row in tables[child_table]}
            source_name = schema["tables"][parent_table]["source"]
            for index, row in enumerate(tables[parent_table]):
                value = row[parent_field]
                if value not in child_values:
                    _issue(
                        issues,
                        source_name,
                        parent_table,
                        row_lines[parent_table][index],
                        parent_field,
                        str(value),
                        f"at least one {child_table}.{child_field} child row",
                        value,
                        f"add a row to {schema['tables'][child_table]['source']}",
                    )
        elif constraint_type == "required_when":
            table_name = constraint["table"]
            source_name = schema["tables"][table_name]["source"]
            when_field = constraint["when_field"]
            expected_value = constraint["equals"]
            required_field = constraint["required_field"]
            primary_field = schema["tables"][table_name]["primary_key"][0]
            for index, row in enumerate(tables[table_name]):
                if row.get(when_field) == expected_value and not row.get(required_field):
                    _issue(
                        issues,
                        source_name,
                        table_name,
                        row_lines[table_name][index],
                        required_field,
                        str(row.get(primary_field, "")),
                        f"non-empty value when {when_field}={expected_value}",
                        row.get(required_field, ""),
                        f"set {required_field} to a valid referenced ID",
                    )
        elif constraint_type == "typed_value":
            table_name = constraint["table"]
            type_field = constraint["type_field"]
            value_field = constraint["value_field"]
            source_name = schema["tables"][table_name]["source"]
            primary_field = schema["tables"][table_name]["primary_key"][0]
            for index, row in enumerate(tables[table_name]):
                value_type = str(row.get(type_field, ""))
                raw_value = str(row.get(value_field, ""))
                try:
                    if value_type == "int":
                        converted: Any = int(raw_value, 10)
                    elif value_type == "float":
                        converted = float(raw_value)
                        if not math.isfinite(converted):
                            raise ValueError("number must be finite")
                    elif value_type == "bool":
                        normalized = raw_value.strip().lower()
                        if normalized not in {"true", "false"}:
                            raise ValueError("boolean must be true or false")
                        converted = normalized == "true"
                    elif value_type == "string":
                        converted = raw_value
                    else:
                        raise ValueError(f"unsupported value_type {value_type}")
                    row[value_field] = converted
                except ValueError as exc:
                    _issue(
                        issues,
                        source_name,
                        table_name,
                        row_lines[table_name][index],
                        value_field,
                        str(row.get(primary_field, "")),
                        f"value compatible with {type_field}={value_type}",
                        raw_value,
                        str(exc),
                    )
        elif constraint_type == "numeric_range":
            table_name = constraint["table"]
            value_field = constraint["value_field"]
            minimum_field = constraint["minimum_field"]
            maximum_field = constraint["maximum_field"]
            source_name = schema["tables"][table_name]["source"]
            primary_field = schema["tables"][table_name]["primary_key"][0]
            for index, row in enumerate(tables[table_name]):
                value = float(row[value_field])
                minimum = float(row[minimum_field])
                maximum = float(row[maximum_field])
                if minimum > maximum or value < minimum or value > maximum:
                    _issue(
                        issues,
                        source_name,
                        table_name,
                        row_lines[table_name][index],
                        value_field,
                        str(row.get(primary_field, "")),
                        f"{minimum_field} <= {value_field} <= {maximum_field}",
                        value,
                        "fix the value or its declared range",
                    )
        else:
            raise ValueError(f"unsupported constraint: {constraint_type}")
