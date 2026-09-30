"""Field normalization and structured validation diagnostics."""
from __future__ import annotations

import math
import re
from dataclasses import dataclass
from typing import Any

ID_PATTERN = re.compile(r"^[a-z][a-z0-9_.-]*$")
SUPPORTED_TYPES = {"bool", "enum", "float", "id", "int", "ref", "res_path", "string"}


@dataclass(frozen=True)
class ValidationIssue:
    source: str
    table: str
    row: int
    field: str
    content_id: str
    expected: str
    actual: str
    suggestion: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "source": self.source,
            "table": self.table,
            "row": self.row,
            "field": self.field,
            "content_id": self.content_id,
            "expected": self.expected,
            "actual": self.actual,
            "suggestion": self.suggestion,
        }

    def __str__(self) -> str:
        location = f"{self.source}:{self.row}:{self.field}"
        return (
            f"[{location}] table={self.table} id={self.content_id or '<unknown>'} "
            f"expected={self.expected}; actual={self.actual!r}; fix={self.suggestion}"
        )



class ContentValidationError(Exception):
    def __init__(self, issues: list[ValidationIssue]):
        self.issues = sorted(
            issues,
            key=lambda issue: (issue.source, issue.row, issue.field, issue.actual),
        )
        super().__init__(f"content validation failed with {len(self.issues)} issue(s)")



def _issue(
    issues: list[ValidationIssue],
    source: str,
    table: str,
    row: int,
    field: str,
    content_id: str,
    expected: str,
    actual: Any,
    suggestion: str,
) -> None:
    issues.append(
        ValidationIssue(
            source=source,
            table=table,
            row=row,
            field=field,
            content_id=content_id,
            expected=expected,
            actual=str(actual),
            suggestion=suggestion,
        )
    )



def _normalize_value(
    raw_value: str,
    field_schema: dict[str, Any],
    context: dict[str, Any],
    issues: list[ValidationIssue],
) -> Any:
    field_name = field_schema["name"]
    value_type = field_schema["type"]
    required = bool(field_schema.get("required", False))
    value = raw_value if value_type == "string" else raw_value.strip()

    if not value.strip():
        if required:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"required {value_type}",
                actual=raw_value,
                suggestion="provide a non-empty value",
            )
        return ""

    if value_type == "int":
        try:
            parsed = int(value, 10)
        except ValueError:
            _issue(
                issues,
                **context,
                field=field_name,
                expected="base-10 integer",
                actual=raw_value,
                suggestion="replace the value with an integer such as 0 or 12",
            )
            return 0
        minimum = field_schema.get("min")
        maximum = field_schema.get("max")
        if minimum is not None and parsed < minimum:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"integer >= {minimum}",
                actual=raw_value,
                suggestion=f"raise the value to at least {minimum}",
            )
        if maximum is not None and parsed > maximum:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"integer <= {maximum}",
                actual=raw_value,
                suggestion=f"lower the value to at most {maximum}",
            )
        return parsed

    if value_type == "float":
        try:
            parsed_float = float(value)
        except ValueError:
            parsed_float = math.nan
        if not math.isfinite(parsed_float):
            _issue(
                issues,
                **context,
                field=field_name,
                expected="finite decimal number",
                actual=raw_value,
                suggestion="replace the value with a finite number such as 0.5 or 12",
            )
            return 0.0
        minimum = field_schema.get("min")
        maximum = field_schema.get("max")
        if minimum is not None and parsed_float < minimum:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"number >= {minimum}",
                actual=raw_value,
                suggestion=f"raise the value to at least {minimum}",
            )
        if maximum is not None and parsed_float > maximum:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"number <= {maximum}",
                actual=raw_value,
                suggestion=f"lower the value to at most {maximum}",
            )
        return parsed_float

    if value_type == "bool":
        normalized_bool = value.lower()
        if normalized_bool in {"true", "1", "yes"}:
            return True
        if normalized_bool in {"false", "0", "no"}:
            return False
        _issue(
            issues,
            **context,
            field=field_name,
            expected="boolean: true or false",
            actual=raw_value,
            suggestion="use true or false",
        )
        return False

    if value_type in {"id", "ref"} and not ID_PATTERN.fullmatch(value):
        _issue(
            issues,
            **context,
            field=field_name,
            expected="stable lowercase ID: [a-z][a-z0-9_.-]*",
            actual=raw_value,
            suggestion="use a stable lowercase ID; never use a display name as an ID",
        )

    if value_type == "enum":
        allowed = field_schema.get("values", [])
        if value not in allowed:
            _issue(
                issues,
                **context,
                field=field_name,
                expected=f"one of {allowed}",
                actual=raw_value,
                suggestion="choose a declared enum value or update the schema and runtime handler",
            )
    if value_type == "res_path":
        if not value.startswith("res://") or ".." in value or "\\" in value:
            _issue(
                issues,
                **context,
                field=field_name,
                expected="normalized res:// path without traversal or backslashes",
                actual=raw_value,
                suggestion="use a project-relative path such as res://assets/runtime/ui/icon.svg",
            )
    return value
