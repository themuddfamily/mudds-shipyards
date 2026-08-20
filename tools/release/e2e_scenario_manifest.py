#!/usr/bin/env python3
"""Validate a bounded end-to-end scenario and re-entry evidence manifest.

The manifest is a declaration of what a packaged playthrough must exercise; it
is not a substitute for a human run.  In particular, a checked-in ``pending``
record is valid planning evidence, while a ``pass`` record must carry a source
revision, package result, and one passing run for every required fresh process.
This keeps lifecycle intent, re-entry invariants, and observed evidence
separate and fail-closed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
MANIFEST_KIND = "keths_end_to_end_scenario"
ID_RE = re.compile(r"^[a-z][a-z0-9_]{2,63}$")
SHA_RE = re.compile(r"^[0-9a-f]{40,64}$")
STEP_ORDER = (
    "cold_boot",
    "begin",
    "walk",
    "board",
    "automatic_propulsion",
    "physical_launch",
    "combat",
    "destruction",
    "recovery",
    "landing",
    "activity",
    "disembark",
    "save",
    "restart",
    "pause_resume",
    "settings",
    "camera_modes",
    "return",
    "long_session_teardown",
)
STEP_RANK = {name: index for index, name in enumerate(STEP_ORDER)}
EVIDENCE_STATUSES = {"pending", "pass", "fail"}
PACKAGE_STATUSES = {"not_run", "pass", "fail"}


def _is_nonempty_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _unique_text_list(value: Any, label: str, errors: list[str]) -> list[str]:
    if not isinstance(value, list) or not value:
        errors.append(f"{label} must be a non-empty list")
        return []
    result: list[str] = []
    for item in value:
        if not _is_nonempty_text(item):
            errors.append(f"{label} entries must be non-empty text")
            continue
        result.append(item)
    if len(set(result)) != len(result):
        errors.append(f"{label} contains duplicates")
    return result


def _safe_relative_path(value: Any, label: str, errors: list[str]) -> None:
    if not _is_nonempty_text(value):
        errors.append(f"{label} must be non-empty text")
        return
    path = value.replace("\\", "/")
    if path.startswith("/") or path.startswith("~") or ".." in path.split("/"):
        errors.append(f"{label} must be a safe relative path")


def _validate_source(source: Any, errors: list[str]) -> None:
    if not isinstance(source, dict):
        errors.append("source must be an object")
        return
    status = source.get("status")
    if status not in {"pending", "recorded"}:
        errors.append("source.status must be pending or recorded")
    revision = source.get("git_sha")
    if revision is not None and (not isinstance(revision, str) or not SHA_RE.fullmatch(revision)):
        errors.append("source.git_sha must be null or a lowercase commit SHA")
    dirty = source.get("git_dirty")
    if dirty is not None and not isinstance(dirty, bool):
        errors.append("source.git_dirty must be null or boolean")
    if status == "recorded" and (not SHA_RE.fullmatch(revision or "") or dirty is not False):
        errors.append("recorded source requires git_sha and git_dirty=false")


def _validate_reentry(reentry: Any, errors: list[str]) -> None:
    if not isinstance(reentry, dict):
        errors.append("reentry must be an object")
        return
    if reentry.get("boundary") != "whole_main":
        errors.append("reentry.boundary must be whole_main")
    identity = _unique_text_list(reentry.get("identity_fields"), "reentry.identity_fields", errors)
    preserved = _unique_text_list(reentry.get("preserved_fields"), "reentry.preserved_fields", errors)
    reset = _unique_text_list(reentry.get("reset_fields"), "reentry.reset_fields", errors)
    overlap = sorted(set(preserved) & set(reset))
    if overlap:
        errors.append(f"reentry.preserved_fields and reset_fields overlap: {', '.join(overlap)}")
    if "generation" not in identity:
        errors.append("reentry.identity_fields must include generation")
    if not _is_nonempty_text(reentry.get("generation_field")):
        errors.append("reentry.generation_field is required")
    if not _is_nonempty_text(reentry.get("resume_phase")):
        errors.append("reentry.resume_phase is required")
    for key in ("stale_generation_rejected", "duplicate_completion_rejected"):
        if reentry.get(key) is not True:
            errors.append(f"reentry.{key} must be true")


def _validate_evidence(
    evidence: Any,
    scenario_id: str,
    minimum_runs: int,
    root: Path | None,
    errors: list[str],
) -> None:
    label = f"scenario {scenario_id} evidence"
    if not isinstance(evidence, dict):
        errors.append(f"{label} must be an object")
        return
    status = evidence.get("status")
    if status not in EVIDENCE_STATUSES:
        errors.append(f"{label}.status must be one of {sorted(EVIDENCE_STATUSES)}")
    package = evidence.get("package")
    if package not in PACKAGE_STATUSES:
        errors.append(f"{label}.package must be one of {sorted(PACKAGE_STATUSES)}")
    commit = evidence.get("source_commit")
    if commit is not None and (not isinstance(commit, str) or not SHA_RE.fullmatch(commit)):
        errors.append(f"{label}.source_commit must be null or a lowercase commit SHA")
    artifacts = evidence.get("artifacts", [])
    if not isinstance(artifacts, list):
        errors.append(f"{label}.artifacts must be a list")
        artifacts = []
    for index, artifact in enumerate(artifacts):
        artifact_label = f"{label}.artifacts[{index}]"
        if not isinstance(artifact, dict):
            errors.append(f"{artifact_label} must be an object")
            continue
        _safe_relative_path(artifact.get("path"), f"{artifact_label}.path", errors)
        digest = artifact.get("sha256")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            errors.append(f"{artifact_label}.sha256 must be a lowercase SHA-256")
        if root is not None and _is_nonempty_text(artifact.get("path")):
            path = (root / artifact["path"]).resolve()
            if root.resolve() not in path.parents:
                errors.append(f"{artifact_label}.path escapes repository root")
            elif not path.is_file():
                errors.append(f"{artifact_label}.path does not exist: {artifact['path']}")
            elif isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest):
                actual = hashlib.sha256(path.read_bytes()).hexdigest()
                if actual != digest:
                    errors.append(f"{artifact_label}.sha256 does not match file")
    runs = evidence.get("runs", [])
    if not isinstance(runs, list):
        errors.append(f"{label}.runs must be a list")
        runs = []
    seen_run_ids: set[str] = set()
    passing_runs = 0
    for index, run in enumerate(runs):
        run_label = f"{label}.runs[{index}]"
        if not isinstance(run, dict):
            errors.append(f"{run_label} must be an object")
            continue
        run_id = run.get("id")
        if not _is_nonempty_text(run_id) or run_id in seen_run_ids:
            errors.append(f"{run_label}.id must be unique non-empty text")
        else:
            seen_run_ids.add(run_id)
        if run.get("result") not in {"pass", "fail"}:
            errors.append(f"{run_label}.result must be pass or fail")
        elif run["result"] == "pass":
            passing_runs += 1
        if run.get("fresh_process") is not True:
            errors.append(f"{run_label}.fresh_process must be true")
    if status == "pass":
        if not SHA_RE.fullmatch(commit or ""):
            errors.append(f"{label}.source_commit is required for pass")
        if package != "pass":
            errors.append(f"{label}.package must be pass for pass evidence")
        if passing_runs < minimum_runs:
            errors.append(f"{label} needs at least {minimum_runs} passing fresh-process runs")
    if status == "pending" and (commit is not None or package == "pass"):
        errors.append(f"{label} pending status cannot claim source or package success")


def validate_manifest(manifest: dict[str, Any], root: Path | None = None) -> list[str]:
    """Return blocking schema/consistency errors; an empty list means valid."""
    errors: list[str] = []
    if not isinstance(manifest, dict):
        return ["manifest must be an object"]
    if manifest.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if manifest.get("manifest_kind") != MANIFEST_KIND:
        errors.append(f"manifest_kind must be {MANIFEST_KIND}")
    _validate_source(manifest.get("source"), errors)
    scenarios = manifest.get("scenarios")
    if not isinstance(scenarios, list) or not scenarios:
        errors.append("scenarios must be a non-empty list")
        scenarios = []
    seen_ids: set[str] = set()
    for scenario in scenarios:
        if not isinstance(scenario, dict):
            errors.append("scenario entries must be objects")
            continue
        scenario_id = scenario.get("id")
        if not isinstance(scenario_id, str) or not ID_RE.fullmatch(scenario_id):
            errors.append(f"scenario id is invalid: {scenario_id!r}")
            scenario_id = "unknown"
        elif scenario_id in seen_ids:
            errors.append(f"duplicate scenario id: {scenario_id}")
        else:
            seen_ids.add(scenario_id)
        crafts = _unique_text_list(scenario.get("crafts"), f"scenario {scenario_id} crafts", errors)
        if not crafts:
            errors.append(f"scenario {scenario_id} must name at least one craft")
        repeat = scenario.get("repeat_policy")
        minimum_runs = 0
        if not isinstance(repeat, dict):
            errors.append(f"scenario {scenario_id} repeat_policy must be an object")
        else:
            minimum_runs = repeat.get("fresh_process_passes", 0)
            if not isinstance(minimum_runs, int) or isinstance(minimum_runs, bool) or minimum_runs < 1:
                errors.append(f"scenario {scenario_id} repeat_policy.fresh_process_passes must be positive")
                minimum_runs = 1
            repeats = repeat.get("same_world_repeats")
            if not isinstance(repeats, int) or isinstance(repeats, bool) or repeats < 1:
                errors.append(f"scenario {scenario_id} repeat_policy.same_world_repeats must be positive")
        steps = scenario.get("steps")
        if not isinstance(steps, list) or not steps:
            errors.append(f"scenario {scenario_id} steps must be a non-empty list")
            steps = []
        seen_steps: set[str] = set()
        last_rank = -1
        for step in steps:
            if not isinstance(step, dict):
                errors.append(f"scenario {scenario_id} step entries must be objects")
                continue
            step_id = step.get("id")
            kind = step.get("kind")
            if not _is_nonempty_text(step_id) or step_id in seen_steps:
                errors.append(f"scenario {scenario_id} step ids must be unique non-empty text")
            else:
                seen_steps.add(step_id)
            if kind not in STEP_RANK:
                errors.append(f"scenario {scenario_id} has unsupported step kind: {kind!r}")
            elif STEP_RANK[kind] < last_rank:
                errors.append(f"scenario {scenario_id} steps are out of lifecycle order at {kind}")
            else:
                last_rank = STEP_RANK[kind]
            if not _is_nonempty_text(step.get("expected")):
                errors.append(f"scenario {scenario_id} step {step_id!r} expected is required")
        _validate_reentry(scenario.get("reentry"), errors)
        _validate_evidence(scenario.get("evidence"), scenario_id, minimum_runs, root, errors)
    required = manifest.get("required_scenario_ids")
    required_ids = _unique_text_list(required, "required_scenario_ids", errors)
    for scenario_id in required_ids:
        if scenario_id not in seen_ids:
            errors.append(f"required scenario is not declared: {scenario_id}")
    return errors


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--root", type=Path, help="repository root for artifact checks")
    args = parser.parse_args()
    try:
        manifest = _load_json(args.manifest)
        errors = validate_manifest(manifest, args.root.resolve() if args.root else None)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"E2E_SCENARIO_MANIFEST_INVALID: {exc}", file=sys.stderr)
        return 1
    if errors:
        print("E2E_SCENARIO_MANIFEST_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    count = len(manifest["scenarios"])
    print(f"E2E_SCENARIO_MANIFEST_VALID: {args.manifest} ({count} scenario(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
