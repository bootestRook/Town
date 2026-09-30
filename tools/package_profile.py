"""Display, export preset, adaptation, and font contract validation."""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROFILE_PATH = PROJECT_ROOT / "package_profiles.json"
WEB_RESIZE_POLICIES = {"none": 0, "project": 1, "adaptive": 2}
MAX_WEB_ARCHIVE_BYTES = 100_000_000
FONT_SUFFIXES = {".ttf", ".otf", ".woff", ".woff2", ".fnt"}


def _godot_value(raw: str) -> Any:
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"'):
        return json.loads(raw)
    if raw == "true":
        return True
    if raw == "false":
        return False
    try:
        return int(raw)
    except ValueError:
        return raw



def read_godot_config(path: Path) -> dict[str, dict[str, Any]]:
    sections: dict[str, dict[str, Any]] = {"": {}}
    current = sections[""]
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = sections.setdefault(line[1:-1], {})
            continue
        if "=" not in line:
            raise ValueError(f"{path.name}:{line_number}: expected key=value")
        key, value = line.split("=", 1)
        current[key.strip()] = _godot_value(value)
    return sections



def load_profiles(path: Path = PROFILE_PATH) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("package_profiles.json must contain an object")
    return data



def _resolution(value: Any, label: str, issues: list[str]) -> tuple[int, int] | None:
    if (
        not isinstance(value, list)
        or len(value) != 2
        or any(isinstance(item, bool) or not isinstance(item, int) or item <= 0 for item in value)
    ):
        issues.append(f"{label} must be [positive_width, positive_height]")
        return None
    return value[0], value[1]



def _relative_output(value: Any, issues: list[str], label: str = "output") -> str | None:
    if not isinstance(value, str) or not value:
        issues.append(f"{label} must be a non-empty relative path")
        return None
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or not path.parts or path.parts[0] != "build":
        issues.append(f"{label} must stay under build/")
        return None
    return path.as_posix()



def _bundled_fonts(value: Any, root: Path, issues: list[str]) -> list[str]:
    if not isinstance(value, list) or not value:
        issues.append("bundled_font_files must list at least one shipped font")
        return []
    fonts: list[str] = []
    runtime_root = (root / "assets" / "runtime").resolve()
    for index, item in enumerate(value):
        if not isinstance(item, str) or not item:
            issues.append(f"bundled_font_files[{index}] must be a path")
            continue
        path = (root / item).resolve()
        if not path.is_relative_to(runtime_root) or path.suffix.lower() not in FONT_SUFFIXES:
            issues.append(f"bundled font must be a supported file under assets/runtime/: {item}")
        elif not path.is_file():
            issues.append(f"bundled font does not exist: {item}")
        else:
            fonts.append(Path(item).as_posix())
    return fonts



def _find_preset(
    presets: dict[str, dict[str, Any]], name: Any
) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    for section, values in presets.items():
        if section.startswith("preset.") and not section.endswith(".options") and values.get("name") == name:
            return values, presets.get(f"{section}.options", {})
    return None, None



def validate_profile(
    profile_name: str,
    root: Path = PROJECT_ROOT,
    config: dict[str, Any] | None = None,
    require_confirmation: bool = True,
    require_adaptation_review: bool = True,
) -> tuple[list[str], dict[str, Any]]:
    issues: list[str] = []
    config = config if config is not None else load_profiles(root / "package_profiles.json")
    if config.get("format_version") != 1:
        issues.append("format_version must be 1")

    design = config.get("design")
    profiles = config.get("profiles")
    if not isinstance(design, dict):
        return issues + ["design must be an object"], {}
    if not isinstance(profiles, dict) or profile_name not in profiles:
        return issues + [f"unknown profile: {profile_name}"], {}
    profile = profiles[profile_name]
    if not isinstance(profile, dict):
        return issues + [f"profiles.{profile_name} must be an object"], {}

    project = read_godot_config(root / "project.godot")
    display = project.get("display", {})
    rendering = project.get("rendering", {})
    project_resolution = _resolution(
        [
            display.get("window/size/viewport_width"),
            display.get("window/size/viewport_height"),
        ],
        "project viewport resolution",
        issues,
    )
    resolution = profile.get("resolution")
    design_resolution: tuple[int, int] | None = None
    if not isinstance(resolution, dict):
        issues.append("resolution must be an object")
    elif resolution.get("mode") == "project":
        design_resolution = project_resolution
        if resolution.get("override") is not None:
            issues.append("project resolution mode must not define an override")
    elif resolution.get("mode") == "special":
        design_resolution = _resolution(
            resolution.get("override"), "resolution.override", issues
        )
        if not isinstance(resolution.get("reason"), str) or not resolution["reason"].strip():
            issues.append("special resolution requires a non-empty reason")
        if design_resolution and project_resolution != design_resolution:
            issues.append("special resolution must be applied to project.godot before packaging")
    else:
        issues.append("resolution.mode must be project or special")
    test_values = profile.get("test_resolutions")
    test_resolutions: list[tuple[int, int]] = []
    if not isinstance(test_values, list) or len(test_values) < 3:
        issues.append("test_resolutions must contain at least 3 sizes")
    elif isinstance(test_values, list):
        for index, value in enumerate(test_values):
            parsed = _resolution(value, f"test_resolutions[{index}]", issues)
            if parsed:
                test_resolutions.append(parsed)

    orientations = profile.get("supported_orientations")
    if not isinstance(orientations, list) or not orientations:
        issues.append("supported_orientations must not be empty")
        orientations = []
    else:
        invalid = set(orientations) - {"landscape", "portrait"}
        if invalid:
            issues.append(f"unsupported orientations: {', '.join(sorted(invalid))}")
    if "landscape" in orientations and not any(width > height for width, height in test_resolutions):
        issues.append("test_resolutions has no landscape case")
    if "portrait" in orientations and not any(height > width for width, height in test_resolutions):
        issues.append("test_resolutions has no portrait case")

    confirmation = profile.get("confirmation")
    if not isinstance(confirmation, dict):
        issues.append("confirmation must be an object")
    elif require_confirmation:
        if confirmation.get("resolution_and_mode_confirmed") is not True:
            issues.append("resolution/mode is not confirmed")
        if require_adaptation_review and confirmation.get("adaptation_reviewed") is not True:
            issues.append("target adaptation is not reviewed")

    output = _relative_output(profile.get("output"), issues)
    if display.get("window/stretch/mode") != design.get("stretch_mode"):
        issues.append("project stretch mode does not match design")
    if display.get("window/stretch/aspect") != design.get("stretch_aspect"):
        issues.append("project stretch aspect does not match design")

    presets = read_godot_config(root / "export_presets.cfg")
    preset, options = _find_preset(presets, profile.get("preset"))
    if preset is None:
        issues.append(f"export preset not found: {profile.get('preset')}")
    else:
        if preset.get("platform") != profile.get("platform"):
            issues.append("export preset platform does not match profile")
        preset_output = Path(str(preset.get("export_path", ""))).as_posix()
        if output and preset_output != output:
            issues.append("export preset path does not match profile output")

    if profile_name == "webapp":
        if profile.get("platform") != "Web":
            issues.append("webapp platform must be Web")
        policy = WEB_RESIZE_POLICIES.get(profile.get("canvas_resize_policy"))
        if policy is None:
            issues.append("canvas_resize_policy must be none, project, or adaptive")
        elif options is not None and options.get("html/canvas_resize_policy") != policy:
            issues.append("Web canvas resize policy does not match export preset")
        if output and Path(output).name.lower() != "index.html":
            issues.append("Web output must be named index.html")
        archive = _relative_output(profile.get("archive"), issues, "archive")
        if archive and Path(archive).suffix.lower() != ".zip":
            issues.append("Web archive must be a .zip")
        if archive and Path(archive).parent != Path("build"):
            issues.append("Web archive must be directly under build/")
        max_archive_bytes = profile.get("max_archive_bytes")
        if (
            isinstance(max_archive_bytes, bool)
            or not isinstance(max_archive_bytes, int)
            or not 0 < max_archive_bytes <= MAX_WEB_ARCHIVE_BYTES
        ):
            issues.append(f"max_archive_bytes must be between 1 and {MAX_WEB_ARCHIVE_BYTES}")
        browsers = profile.get("test_browsers")
        if not isinstance(browsers, list) or len(browsers) < 2:
            issues.append("test_browsers must contain at least 2 target browsers")
        locales = profile.get("required_locales")
        if not isinstance(locales, list) or not locales or not all(isinstance(item, str) and item for item in locales):
            issues.append("required_locales must contain locale names")
        if rendering.get("renderer/rendering_method") != "gl_compatibility":
            issues.append("Web projects must be previewed with the gl_compatibility renderer")
        if rendering.get("renderer/rendering_method.mobile") != "gl_compatibility":
            issues.append("Web mobile rendering must use gl_compatibility")
        vram_targets = profile.get("vram_texture_targets")
        if (
            not isinstance(vram_targets, list)
            or not vram_targets
            or set(vram_targets) - {"desktop", "mobile"}
        ):
            issues.append("vram_texture_targets must contain desktop and/or mobile")
        elif options is not None:
            for target in ("desktop", "mobile"):
                expected = target in vram_targets
                if options.get(f"vram_texture_compression/for_{target}") is not expected:
                    issues.append(f"Web {target} VRAM texture target does not match profile")
        if require_adaptation_review:
            _bundled_fonts(profile.get("bundled_font_files"), root, issues)
            if isinstance(confirmation, dict):
                if confirmation.get("color_parity_reviewed") is not True:
                    issues.append("Web color parity is not reviewed")
                if confirmation.get("text_and_font_reviewed") is not True:
                    issues.append("Web text/font rendering is not reviewed")
                if confirmation.get("editor_candidate_parity_reviewed") is not True:
                    issues.append("Godot editor/candidate parity is not reviewed")
    elif profile_name == "exe":
        if profile.get("platform") != "Windows Desktop":
            issues.append("windows platform must be Windows Desktop")
        initial = _resolution(profile.get("initial_window_resolution"), "initial_window_resolution", issues)
        if initial:
            if design_resolution and initial != design_resolution:
                issues.append("initial window resolution must match the packaging resolution")
            if display.get("window/size/window_width_override") != initial[0]:
                issues.append("project initial window width does not match profile")
            if display.get("window/size/window_height_override") != initial[1]:
                issues.append("project initial window height does not match profile")
        if not isinstance(profile.get("resizable"), bool):
            issues.append("resizable must be true or false")
        elif display.get("window/size/resizable", True) != profile["resizable"]:
            issues.append("project resizable setting does not match profile")
        if output and Path(output).suffix.lower() != ".exe":
            issues.append("Windows output must be an .exe")
    else:
        issues.append(f"unsupported profile: {profile_name}")

    summary = {
        "profile": profile_name,
        "design_resolution": list(design_resolution) if design_resolution else None,
        "output": output,
        "test_resolutions": [list(item) for item in test_resolutions],
    }
    if profile_name == "webapp":
        summary["archive"] = archive
        summary["max_archive_bytes"] = profile.get("max_archive_bytes")
    return issues, summary
