#!/usr/bin/env python3
"""Create a deterministic, fail-closed release-candidate evidence record."""

import argparse
import csv
import hashlib
import json
import os
import re
import shlex
import shutil
import struct
import subprocess
import sys
from pathlib import Path, PurePosixPath


SCHEMA_PATH = Path(__file__).with_name("release_candidate.schema.json")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
RUN_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
ARTIFACT_RE = re.compile(
    r"^(?P<prefix>[A-Za-z0-9][A-Za-z0-9._-]*)-(?P<revision>[0-9a-f]{7})\.exe$"
)
FORBIDDEN_PATHS = ("tests/", "artifacts/", "tools/")
RAW_SOURCE_SUFFIXES = (".gd", ".tscn", ".tres")
MAX_JSON_BYTES = 128 << 20
MAX_TSV_BYTES = 64 << 20


class EvidenceError(ValueError):
    """A release gate input is absent, inconsistent, or unsupported."""


def _sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def _sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def _bounded_read(path, limit, description):
    try:
        size = path.stat().st_size
    except OSError as error:
        raise EvidenceError(f"missing {description}: {path}") from error
    if size > limit:
        raise EvidenceError(f"unreasonable {description} size: {path}")
    try:
        return path.read_bytes()
    except OSError as error:
        raise EvidenceError(f"cannot read {description}: {path}") from error


def _require_sha256(value, description):
    if not SHA256_RE.fullmatch(value or ""):
        raise EvidenceError(f"invalid {description} SHA-256: {value!r}")
    return value


def _require_int(values, key, minimum=0):
    try:
        value = int(values[key])
    except (KeyError, ValueError) as error:
        raise EvidenceError(f"missing or invalid integer {key}") from error
    if value < minimum:
        raise EvidenceError(f"{key} must be at least {minimum}")
    return value


def _run(command, cwd=None):
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            env={**os.environ, "LC_ALL": "C"},
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise EvidenceError(f"command failed to start: {command[0]}") from error
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        raise EvidenceError(f"command failed: {' '.join(command)}: {detail}")
    return result.stdout


def inspect_source(repository):
    repository = repository.resolve()
    top = Path(_run(["git", "rev-parse", "--show-toplevel"], repository).strip()).resolve()
    if top != repository:
        raise EvidenceError(f"--repository must be the worktree root: {top}")
    revision = _run(["git", "rev-parse", "HEAD"], repository).strip()
    if not re.fullmatch(r"[0-9a-f]{40,64}", revision):
        raise EvidenceError("git returned an invalid source revision")
    short_revision = _run(
        ["git", "rev-parse", "--short=7", "HEAD"], repository
    ).strip()
    if not re.fullmatch(r"[0-9a-f]{7}", short_revision):
        raise EvidenceError("git returned an invalid seven-character revision")
    dirty_lines = _run(
        ["git", "status", "--porcelain=v1", "--untracked-files=all"], repository
    ).splitlines()
    if dirty_lines:
        preview = ", ".join(line[:160] for line in dirty_lines[:5])
        raise EvidenceError(f"source worktree is dirty: {preview}")
    return {
        "revision": revision,
        "short_revision": short_revision,
        "dirty": False,
    }


def inspect_godot(godot_path):
    resolved = _resolve_command(str(godot_path))
    output = _run([str(resolved), "--version"]).strip()
    if not output or "\n" in output or len(output) > 160:
        raise EvidenceError("Godot --version returned an invalid value")
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)(?:[.-].*)?$", output)
    if not match:
        raise EvidenceError(f"unrecognized Godot version: {output!r}")
    return {
        "path": resolved,
        "version": output,
        "semver": tuple(int(part) for part in match.groups()),
        "sha256": _sha256_file(resolved),
    }


def _resolve_command(command):
    if "/" in command or "\\" in command:
        path = Path(command).expanduser().resolve()
        if not path.is_file() or not os.access(path, os.X_OK):
            raise EvidenceError(f"executable not found: {command}")
        return path
    found = shutil.which(command)
    if not found:
        raise EvidenceError(f"executable not found on PATH: {command}")
    return Path(found).resolve()


def _check_evidence_godot(raw_path, expected_path, description):
    if _resolve_command(raw_path) != expected_path:
        raise EvidenceError(f"{description} used a different Godot executable")


def _parse_key_values(path, description):
    raw = _bounded_read(path, 1 << 20, description)
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        raise EvidenceError(f"{description} is not UTF-8: {path}") from error
    values = {}
    for line_number, line in enumerate(text.splitlines(), 1):
        if not line or "=" not in line:
            raise EvidenceError(f"malformed {description} line {line_number}")
        key, value = line.split("=", 1)
        if not re.fullmatch(r"[a-z][a-z0-9_]*", key) or key in values:
            raise EvidenceError(f"invalid or duplicate {description} key: {key!r}")
        values[key] = value
    return raw, values


def _manifest_file(value, manifest_path, description):
    path = Path(value)
    if not path.is_absolute():
        path = manifest_path.parent / path
    path = path.resolve()
    if not path.is_file():
        raise EvidenceError(f"missing {description}: {path}")
    return path


def _read_tsv(path, required_fields, description):
    raw = _bounded_read(path, MAX_TSV_BYTES, description)
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        raise EvidenceError(f"{description} is not UTF-8") from error
    reader = csv.DictReader(text.splitlines(), delimiter="\t")
    if reader.fieldnames is None or len(reader.fieldnames) != len(set(reader.fieldnames)):
        raise EvidenceError(f"invalid {description} header")
    missing = set(required_fields) - set(reader.fieldnames)
    if missing:
        raise EvidenceError(f"{description} lacks fields: {', '.join(sorted(missing))}")
    rows = list(reader)
    if not rows:
        raise EvidenceError(f"{description} has no result rows")
    return raw, rows


def _safe_scope_path(value):
    path = PurePosixPath(value)
    if (
        not value
        or value.startswith("/")
        or "\\" in value
        or ":" in value
        or any(part in ("", ".", "..") for part in path.parts)
        or path.as_posix() != value
    ):
        raise EvidenceError(f"unsafe matrix manifest scope path: {value!r}")
    return path


def source_scope_manifest(repository, scope_values):
    rows = []
    seen = set()
    for raw_scope in scope_values:
        scope = _safe_scope_path(raw_scope)
        if scope.as_posix() in seen:
            raise EvidenceError(f"duplicate matrix manifest scope: {scope}")
        seen.add(scope.as_posix())
        root = repository.joinpath(*scope.parts)
        if root.is_symlink():
            raise EvidenceError(f"matrix manifest scope cannot be a symlink: {scope}")
        if root.is_file():
            files = [root]
        elif root.is_dir():
            candidates = sorted(root.rglob("*"))
            symlinks = [path for path in candidates if path.is_symlink()]
            if symlinks:
                relative = symlinks[0].relative_to(repository).as_posix()
                raise EvidenceError(f"matrix manifest scope contains a symlink: {relative}")
            files = [path for path in candidates if path.is_file()]
        else:
            raise EvidenceError(f"matrix manifest scope is missing from source: {scope}")
        for path in files:
            relative = path.relative_to(repository).as_posix()
            if "," in relative or "\n" in relative or "\r" in relative:
                raise EvidenceError(f"source path cannot be represented safely: {relative!r}")
            size = path.stat().st_size
            rows.append((relative, size, _sha256_file(path)))
    rows.sort()
    if len(rows) != len({row[0] for row in rows}):
        raise EvidenceError("matrix manifest scopes overlap")
    text = "path,size_bytes,sha256\n" + "".join(
        f"{path},{size},{digest}\n" for path, size, digest in rows
    )
    return text.encode("utf-8"), len(rows)


def validate_matrix(manifest_path, repository, godot):
    raw, values = _parse_key_values(manifest_path, "matrix manifest")
    required = (
        "run_id",
        "run_started_utc",
        "run_completed_utc",
        "godot_binary",
        "overall_status",
        "total_suites",
        "source_manifest_before_sha",
        "source_manifest_after_sha",
        "source_manifest_match",
        "source_manifest_before_count",
        "source_manifest_after_count",
        "source_manifest_before",
        "source_manifest_after",
        "scope_specs",
        "manifest_scope",
        "total_pass_assertions",
        "failed_suite_count",
        "results_canonical_tsv",
        "results_canonical_sha",
    )
    missing = [key for key in required if key not in values]
    if missing:
        raise EvidenceError(f"matrix manifest lacks: {', '.join(missing)}")
    if not RUN_ID_RE.fullmatch(values["run_id"]):
        raise EvidenceError("invalid matrix run_id")
    if values["overall_status"] != "PASS":
        raise EvidenceError("matrix evidence did not PASS")
    if values["source_manifest_match"] != "true":
        raise EvidenceError("matrix source manifest changed during the run")
    if values["scope_specs"] != "all":
        raise EvidenceError("matrix evidence is not a full-scope run")
    if _require_int(values, "failed_suite_count") != 0:
        raise EvidenceError("matrix evidence contains failed suites")
    total_suites = _require_int(values, "total_suites", 1)
    total_assertions = _require_int(values, "total_pass_assertions", 1)
    _check_evidence_godot(values["godot_binary"], godot["path"], "matrix")

    canonical_path = _manifest_file(
        values["results_canonical_tsv"], manifest_path, "canonical matrix results"
    )
    canonical_raw, rows = _read_tsv(
        canonical_path,
        (
            "test_path",
            "status",
            "exit_code",
            "sentinel_count",
            "pass_assertions",
            "diagnostic_count",
            "failure_flags",
        ),
        "canonical matrix results",
    )
    canonical_sha = _require_sha256(
        values["results_canonical_sha"], "canonical matrix results"
    )
    if _sha256_bytes(canonical_raw) != canonical_sha:
        raise EvidenceError("canonical matrix results SHA-256 mismatch")
    if len(rows) != total_suites:
        raise EvidenceError("canonical matrix row count disagrees with total_suites")
    assertions = 0
    for row in rows:
        if (
            row["status"] != "PASS"
            or row["exit_code"] != "0"
            or row["sentinel_count"] != "1"
            or row["diagnostic_count"] != "0"
            or row["failure_flags"]
        ):
            raise EvidenceError(f"failed canonical matrix row: {row['test_path']}")
        try:
            assertions += int(row["pass_assertions"])
        except ValueError as error:
            raise EvidenceError("invalid matrix assertion count") from error
    if assertions != total_assertions:
        raise EvidenceError("matrix assertion total mismatch")

    before_sha = _require_sha256(
        values["source_manifest_before_sha"], "matrix source-before manifest"
    )
    after_sha = _require_sha256(
        values["source_manifest_after_sha"], "matrix source-after manifest"
    )
    if before_sha != after_sha:
        raise EvidenceError("matrix source manifest hashes disagree")
    before_path = _manifest_file(
        values["source_manifest_before"], manifest_path, "matrix source-before manifest"
    )
    after_path = _manifest_file(
        values["source_manifest_after"], manifest_path, "matrix source-after manifest"
    )
    if _sha256_file(before_path) != before_sha or _sha256_file(after_path) != after_sha:
        raise EvidenceError("matrix source manifest file SHA-256 mismatch")
    scope = shlex.split(values["manifest_scope"])
    if not scope:
        raise EvidenceError("matrix manifest_scope is empty")
    computed, computed_count = source_scope_manifest(repository, scope)
    if _sha256_bytes(computed) != before_sha:
        raise EvidenceError("matrix source manifest does not match the clean source revision")
    before_count = _require_int(values, "source_manifest_before_count", 1)
    after_count = _require_int(values, "source_manifest_after_count", 1)
    if before_count != computed_count or after_count != computed_count:
        raise EvidenceError("matrix source manifest count mismatch")

    return {
        "status": "PASS",
        "run_id": values["run_id"],
        "run_started_utc": values["run_started_utc"],
        "run_completed_utc": values["run_completed_utc"],
        "manifest_sha256": _sha256_bytes(raw),
        "canonical_results_sha256": canonical_sha,
        "source_manifest_sha256": before_sha,
        "total_suites": total_suites,
        "total_pass_assertions": total_assertions,
    }


def validate_probes(manifest_path, artifact_path, artifact_sha, godot):
    raw, values = _parse_key_values(manifest_path, "package-probe manifest")
    required = (
        "run_id",
        "run_started_utc",
        "run_completed_utc",
        "package_path",
        "godot_binary",
        "overall_status",
        "total_probes",
        "results_tsv",
    )
    missing = [key for key in required if key not in values]
    if missing:
        raise EvidenceError(f"package-probe manifest lacks: {', '.join(missing)}")
    if not RUN_ID_RE.fullmatch(values["run_id"]):
        raise EvidenceError("invalid package-probe run_id")
    if values["overall_status"] != "PASS":
        raise EvidenceError("package-probe evidence did not PASS")
    total_probes = _require_int(values, "total_probes", 1)
    _check_evidence_godot(values["godot_binary"], godot["path"], "package probes")
    probed_package = _manifest_file(
        values["package_path"], manifest_path, "package-probe artifact"
    )
    if probed_package.name != artifact_path.name or _sha256_file(probed_package) != artifact_sha:
        raise EvidenceError("package probes target a different artifact")

    results_path = _manifest_file(
        values["results_tsv"], manifest_path, "package-probe results"
    )
    results_raw, rows = _read_tsv(
        results_path,
        (
            "test_path",
            "status",
            "exit_code",
            "sentinel_count",
            "pass_assertions",
            "diagnostic_count",
            "log_path",
            "log_sha256",
            "reasons",
        ),
        "package-probe results",
    )
    if len(rows) != total_probes:
        raise EvidenceError("package-probe row count disagrees with total_probes")
    assertions = 0
    for row in rows:
        if (
            row["status"] != "PASS"
            or row["exit_code"] != "0"
            or row["sentinel_count"] != "1"
            or row["diagnostic_count"] != "0"
            or row["reasons"]
        ):
            raise EvidenceError(f"failed package-probe row: {row['test_path']}")
        log_path = _manifest_file(row["log_path"], manifest_path, "package-probe log")
        log_sha = _require_sha256(row["log_sha256"], "package-probe log")
        if _sha256_file(log_path) != log_sha:
            raise EvidenceError(f"package-probe log SHA-256 mismatch: {row['test_path']}")
        try:
            assertions += int(row["pass_assertions"])
        except ValueError as error:
            raise EvidenceError("invalid package-probe assertion count") from error
    if assertions < 1:
        raise EvidenceError("package probes contain no passing assertions")

    return {
        "status": "PASS",
        "run_id": values["run_id"],
        "run_started_utc": values["run_started_utc"],
        "run_completed_utc": values["run_completed_utc"],
        "manifest_sha256": _sha256_bytes(raw),
        "results_sha256": _sha256_bytes(results_raw),
        "total_probes": total_probes,
        "total_pass_assertions": assertions,
    }


def _u16(data, offset):
    return struct.unpack_from("<H", data, offset)[0]


def _u32(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


def _bounded(offset, size, limit, description):
    if offset < 0 or size < 0 or offset > limit or size > limit - offset:
        raise EvidenceError(f"{description} is outside the artifact")
    return offset + size


def _version_quad(ms, ls):
    return [ms >> 16, ms & 0xFFFF, ls >> 16, ls & 0xFFFF]


def _parse_fixed_version(data, sections, resource_rva, resource_size):
    def rva_to_offset(rva, size):
        for section in sections:
            start = section["virtual_address"]
            relative = rva - start
            if (
                start <= rva
                and relative <= section["raw_size"]
                and size <= section["raw_size"] - relative
            ):
                offset = section["raw_offset"] + relative
                _bounded(offset, size, len(data), "PE resource")
                return offset
        raise EvidenceError("PE resource RVA does not map to a section")

    resource_base = rva_to_offset(resource_rva, resource_size)

    def directory_entries(relative):
        _bounded(relative, 16, resource_size, "PE resource directory")
        absolute = resource_base + relative
        _bounded(absolute, 16, len(data), "PE resource directory")
        count = _u16(data, absolute + 12) + _u16(data, absolute + 14)
        if count > 4096:
            raise EvidenceError("unreasonable PE resource directory size")
        _bounded(relative + 16, count * 8, resource_size, "PE resource entries")
        _bounded(absolute + 16, count * 8, len(data), "PE resource entries")
        result = []
        for index in range(count):
            name, target = struct.unpack_from("<II", data, absolute + 16 + index * 8)
            result.append((name, target & 0x7FFFFFFF, bool(target & 0x80000000)))
        return result

    root = directory_entries(0)
    version_types = [entry for entry in root if entry[0] == 16 and entry[2]]
    if len(version_types) != 1:
        raise EvidenceError("PE must contain exactly one RT_VERSION directory")
    names = directory_entries(version_types[0][1])
    if len(names) != 1 or not names[0][2]:
        raise EvidenceError("unsupported PE RT_VERSION name layout")
    languages = directory_entries(names[0][1])
    if not languages or any(entry[2] for entry in languages):
        raise EvidenceError("unsupported PE RT_VERSION language layout")
    language, data_relative, _ = sorted(languages, key=lambda entry: entry[0])[0]
    data_entry = resource_base + data_relative
    _bounded(data_relative, 16, resource_size, "PE version data entry")
    _bounded(data_entry, 16, len(data), "PE version data entry")
    version_rva, version_size, codepage, reserved = struct.unpack_from(
        "<IIII", data, data_entry
    )
    if reserved:
        raise EvidenceError("unsupported PE version resource data entry")
    version_offset = rva_to_offset(version_rva, version_size)
    blob = data[version_offset : version_offset + version_size]
    if len(blob) < 92:
        raise EvidenceError("truncated VS_VERSION_INFO")
    total_length, value_length, value_type = struct.unpack_from("<HHH", blob, 0)
    if total_length > len(blob) or value_length != 52 or value_type != 0:
        raise EvidenceError("invalid VS_VERSION_INFO header")
    cursor = 6
    key_units = []
    while cursor + 2 <= total_length:
        unit = _u16(blob, cursor)
        cursor += 2
        if unit == 0:
            break
        key_units.append(unit)
    else:
        raise EvidenceError("unterminated VS_VERSION_INFO key")
    try:
        key = b"".join(struct.pack("<H", unit) for unit in key_units).decode("utf-16le")
    except UnicodeDecodeError as error:
        raise EvidenceError("invalid VS_VERSION_INFO key") from error
    if key != "VS_VERSION_INFO":
        raise EvidenceError("unexpected PE version resource key")
    value_offset = (cursor + 3) & ~3
    _bounded(value_offset, 52, total_length, "VS_FIXEDFILEINFO")
    fields = struct.unpack_from("<13I", blob, value_offset)
    if fields[0] != 0xFEEF04BD:
        raise EvidenceError("invalid VS_FIXEDFILEINFO signature")
    return {
        "file_version": _version_quad(fields[2], fields[3]),
        "product_version": _version_quad(fields[4], fields[5]),
        "language": language,
        "codepage": codepage,
    }


def inspect_pe(data):
    if len(data) < 64 or data[:2] != b"MZ":
        raise EvidenceError("artifact is not a PE executable")
    pe_offset = _u32(data, 0x3C)
    _bounded(pe_offset, 24, len(data), "PE header")
    if data[pe_offset : pe_offset + 4] != b"PE\0\0":
        raise EvidenceError("artifact has an invalid PE signature")
    machine, section_count, timestamp, _, _, optional_size, _ = struct.unpack_from(
        "<HHIIIHH", data, pe_offset + 4
    )
    if not 1 <= section_count <= 96:
        raise EvidenceError("unreasonable PE section count")
    optional = pe_offset + 24
    _bounded(optional, optional_size, len(data), "PE optional header")
    if optional_size < 240 or _u16(data, optional) != 0x20B:
        raise EvidenceError("release artifact is not PE32+")
    subsystem = _u16(data, optional + 68)
    image_checksum = _u32(data, optional + 64)
    data_directory_count = _u32(data, optional + 108)
    if data_directory_count < 5:
        raise EvidenceError("PE lacks required data directories")
    resource_rva, resource_size = struct.unpack_from("<II", data, optional + 112 + 16)
    certificate_offset, certificate_size = struct.unpack_from(
        "<II", data, optional + 112 + 32
    )
    if not resource_rva or not resource_size:
        raise EvidenceError("PE lacks a version resource directory")

    section_table = optional + optional_size
    _bounded(section_table, section_count * 40, len(data), "PE section table")
    sections = []
    names = []
    for index in range(section_count):
        position = section_table + index * 40
        raw_name = data[position : position + 8].split(b"\0", 1)[0]
        try:
            name = raw_name.decode("ascii")
        except UnicodeDecodeError as error:
            raise EvidenceError("non-ASCII PE section name") from error
        if not name or name in names:
            raise EvidenceError("empty or duplicate PE section name")
        virtual_size, virtual_address, raw_size, raw_offset = struct.unpack_from(
            "<IIII", data, position + 8
        )
        if raw_size:
            _bounded(raw_offset, raw_size, len(data), f"PE section {name}")
        names.append(name)
        sections.append(
            {
                "name": name,
                "virtual_size": virtual_size,
                "virtual_address": virtual_address,
                "raw_size": raw_size,
                "raw_offset": raw_offset,
            }
        )
    fixed_version = _parse_fixed_version(
        data, sections, resource_rva, resource_size
    )

    if bool(certificate_offset) != bool(certificate_size):
        raise EvidenceError("inconsistent PE certificate table")
    certificate_present = bool(certificate_size)
    if certificate_present:
        certificate_end = _bounded(
            certificate_offset, certificate_size, len(data), "PE certificate table"
        )
        cursor = certificate_offset
        while cursor < certificate_end:
            _bounded(cursor, 8, certificate_end, "WIN_CERTIFICATE header")
            certificate_length = _u32(data, cursor)
            if certificate_length < 8 or certificate_length > certificate_end - cursor:
                raise EvidenceError("malformed WIN_CERTIFICATE entry")
            cursor = (cursor + certificate_length + 7) & ~7
        if cursor != certificate_end:
            raise EvidenceError("misaligned PE certificate table")

    return {
        "pe": {
            "format": "PE32+",
            "machine": machine,
            "subsystem": subsystem,
            "coff_timestamp": timestamp,
            "image_checksum": image_checksum,
            "sections": names,
            "file_version": fixed_version["file_version"],
            "product_version": fixed_version["product_version"],
        },
        "signing": {
            "status": (
                "embedded_certificate_present_unverified"
                if certificate_present
                else "unsigned"
            ),
            "embedded_certificate_present": certificate_present,
            "certificate_table_offset": certificate_offset,
            "certificate_table_size": certificate_size,
            "cryptographic_signature_verified": False,
            "external_catalog_assessed": False,
        },
    }


def _safe_inventory_path(value):
    if not isinstance(value, str):
        raise EvidenceError("inventory entry path is not a string")
    path = PurePosixPath(value)
    if (
        not value
        or value.startswith("/")
        or "\\" in value
        or ":" in value
        or any(part in ("", ".", "..") for part in path.parts)
        or path.as_posix() != value
    ):
        raise EvidenceError(f"unsafe inventory path: {value!r}")
    lowered = value.lower()
    if lowered.startswith(FORBIDDEN_PATHS) or lowered.endswith(RAW_SOURCE_SUFFIXES):
        raise EvidenceError(f"forbidden inventory path: {value}")
    return value


def validate_inventory(inventory_path, artifact_path, artifact_data, artifact_sha, godot):
    raw = _bounded_read(inventory_path, MAX_JSON_BYTES, "package inventory")
    try:
        inventory = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise EvidenceError("package inventory is not valid UTF-8 JSON") from error
    if not isinstance(inventory, dict) or inventory.get("schema_version") != 1:
        raise EvidenceError("unsupported package-inventory schema")
    executable = inventory.get("executable")
    pck = inventory.get("pck")
    entries = inventory.get("entries")
    if not isinstance(executable, dict) or not isinstance(pck, dict) or not isinstance(entries, list):
        raise EvidenceError("package inventory lacks required objects")
    if (
        executable.get("sha256") != artifact_sha
        or executable.get("size") != len(artifact_data)
        or Path(str(executable.get("path", ""))).name != artifact_path.name
    ):
        raise EvidenceError("package inventory describes a different artifact")
    entry_count = pck.get("entry_count")
    if not isinstance(entry_count, int) or entry_count < 1 or entry_count != len(entries):
        raise EvidenceError("package inventory entry count mismatch")
    if pck.get("format") not in (3, 4):
        raise EvidenceError("unsupported inventory PCK format")
    if pck.get("godot_version") != list(godot["semver"]):
        raise EvidenceError("inventory PCK Godot version disagrees with the toolchain")
    pck_offset = pck.get("offset")
    pck_size = pck.get("size")
    if (
        not isinstance(pck_offset, int)
        or not isinstance(pck_size, int)
        or pck_offset < 0
        or pck_size < 1
        or pck_size > len(artifact_data) - pck_offset
    ):
        raise EvidenceError("inventory PCK bounds are invalid")
    if len(artifact_data) < 12 or artifact_data[-4:] != b"GDPC":
        raise EvidenceError("artifact lacks the embedded PCK trailer")
    declared_pck_size = struct.unpack_from("<Q", artifact_data, len(artifact_data) - 12)[0]
    expected_pck_offset = len(artifact_data) - 12 - declared_pck_size
    if pck_offset != expected_pck_offset or pck_size != declared_pck_size:
        raise EvidenceError("inventory PCK bounds disagree with the artifact trailer")

    paths = []
    regions = []
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise EvidenceError(f"inventory entry {index} is not an object")
        path = _safe_inventory_path(entry.get("path"))
        offset = entry.get("offset")
        size = entry.get("size")
        if (
            not isinstance(offset, int)
            or not isinstance(size, int)
            or offset < 0
            or size < 0
            or size > len(artifact_data) - offset
            or offset < pck_offset
            or size > pck_offset + pck_size - offset
        ):
            raise EvidenceError(f"inventory entry bounds are invalid: {path}")
        if entry.get("flags") != 0:
            raise EvidenceError(f"inventory entry has unsupported flags: {path}")
        payload = artifact_data[offset : offset + size]
        if entry.get("sha256") != _sha256_bytes(payload):
            raise EvidenceError(f"inventory entry SHA-256 mismatch: {path}")
        if entry.get("pck_md5") != hashlib.md5(payload, usedforsecurity=False).hexdigest():
            raise EvidenceError(f"inventory entry PCK MD5 mismatch: {path}")
        paths.append(path)
        if size:
            regions.append((offset, offset + size, path))
    if paths != sorted(paths) or len(paths) != len(set(paths)):
        raise EvidenceError("package inventory paths are not unique and sorted")
    if len({path.casefold() for path in paths}) != len(paths):
        raise EvidenceError("package inventory contains case-colliding paths")
    regions.sort()
    for previous, current in zip(regions, regions[1:]):
        if current[0] < previous[1]:
            raise EvidenceError(
                f"overlapping package inventory entries: {previous[2]} and {current[2]}"
            )
    path_manifest_sha = _sha256_bytes("\n".join(paths).encode("utf-8"))
    if pck.get("sorted_path_manifest_sha256") != path_manifest_sha:
        raise EvidenceError("package inventory path-manifest SHA-256 mismatch")

    return {
        "status": "PASS",
        "manifest_sha256": _sha256_bytes(raw),
        "path_manifest_sha256": path_manifest_sha,
        "entry_count": entry_count,
        "pck_format": pck["format"],
        "pck_offset": pck_offset,
        "pck_size": pck_size,
    }


def validate_record_schema(record):
    try:
        import jsonschema
    except ImportError as error:
        raise EvidenceError("Python jsonschema is required to validate the candidate record") from error
    try:
        schema = json.loads(_bounded_read(SCHEMA_PATH, 1 << 20, "candidate schema"))
        jsonschema.Draft202012Validator.check_schema(schema)
        validator = jsonschema.Draft202012Validator(
            schema, format_checker=jsonschema.FormatChecker()
        )
        errors = sorted(validator.iter_errors(record), key=lambda item: list(item.path))
    except (json.JSONDecodeError, jsonschema.SchemaError) as error:
        raise EvidenceError(f"invalid candidate schema: {error}") from error
    if errors:
        error = errors[0]
        location = ".".join(str(part) for part in error.path) or "<root>"
        raise EvidenceError(f"candidate record violates schema at {location}: {error.message}")


def build_candidate(repository, artifact_path, matrix_manifest, probe_manifest, inventory_path, godot_path):
    repository = repository.resolve()
    source = inspect_source(repository)
    artifact_match = ARTIFACT_RE.fullmatch(artifact_path.name)
    if not artifact_match:
        raise EvidenceError("artifact name must end in a seven-character lowercase source SHA")
    artifact_revision = artifact_match.group("revision")
    if artifact_revision != source["short_revision"]:
        raise EvidenceError(
            f"artifact short SHA {artifact_revision} does not match source {source['short_revision']}"
        )
    artifact_data = _bounded_read(artifact_path, 2 << 30, "release artifact")
    artifact_sha = _sha256_bytes(artifact_data)
    godot = inspect_godot(godot_path)
    pe = inspect_pe(artifact_data)
    matrix = validate_matrix(matrix_manifest, repository, godot)
    probes = validate_probes(
        probe_manifest, artifact_path, artifact_sha, godot
    )
    inventory = validate_inventory(
        inventory_path, artifact_path, artifact_data, artifact_sha, godot
    )

    source["matrix_scope_manifest_sha256"] = matrix["source_manifest_sha256"]
    record = {
        "schema_version": 1,
        "candidate_id": artifact_path.stem,
        "status": "PASS",
        "source": source,
        "toolchain": {
            "godot_version": godot["version"],
            "godot_executable_sha256": godot["sha256"],
        },
        "artifact": {
            "name": artifact_path.name,
            "size": len(artifact_data),
            "sha256": artifact_sha,
            "source_short_revision": artifact_revision,
            "pe": pe["pe"],
            "signing": pe["signing"],
        },
        "evidence": {
            "matrix": matrix,
            "package_probes": probes,
            "package_inventory": inventory,
        },
    }
    final_source = inspect_source(repository)
    if any(final_source[key] != source[key] for key in final_source):
        raise EvidenceError("source worktree changed while candidate evidence was validated")
    validate_record_schema(record)
    return record


def write_candidate(record, artifact_path, output_directory):
    output_directory = output_directory.resolve()
    if output_directory != artifact_path.resolve().parent:
        raise EvidenceError("candidate record and SHA256SUMS must be written beside the artifact")
    record_path = output_directory / f"{artifact_path.stem}.release.json"
    sums_path = output_directory / "SHA256SUMS"
    if record_path.exists() or sums_path.exists():
        raise EvidenceError("candidate record or SHA256SUMS already exists")
    record_bytes = (json.dumps(record, sort_keys=True, indent=2) + "\n").encode("utf-8")
    sums = {
        artifact_path.name: record["artifact"]["sha256"],
        record_path.name: _sha256_bytes(record_bytes),
    }
    sums_bytes = "".join(
        f"{digest}  {name}\n" for name, digest in sorted(sums.items())
    ).encode("ascii")
    created = []
    try:
        with record_path.open("xb") as stream:
            stream.write(record_bytes)
        created.append(record_path)
        with sums_path.open("xb") as stream:
            stream.write(sums_bytes)
        created.append(sums_path)
    except OSError as error:
        # A record without its checksum companion is never a valid output.
        for path in created:
            try:
                path.unlink(missing_ok=True)
            except OSError:
                pass
        raise EvidenceError(f"cannot write candidate evidence: {error}") from error
    return record_path, sums_path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--matrix-manifest", type=Path, required=True)
    parser.add_argument("--probe-manifest", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output-directory", type=Path)
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="validate all inputs and print the canonical record without writing files",
    )
    args = parser.parse_args(argv)
    try:
        artifact = args.artifact.resolve()
        record = build_candidate(
            args.repository,
            artifact,
            args.matrix_manifest.resolve(),
            args.probe_manifest.resolve(),
            args.inventory.resolve(),
            args.godot,
        )
        if args.check_only:
            sys.stdout.write(json.dumps(record, sort_keys=True, indent=2) + "\n")
        else:
            output_directory = args.output_directory or artifact.parent
            record_path, sums_path = write_candidate(record, artifact, output_directory)
            print(f"release-candidate: PASS: {record_path}")
            print(f"release-candidate: SHA256SUMS: {sums_path}")
    except (EvidenceError, OSError, struct.error) as error:
        print(f"release-candidate: ERROR: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
