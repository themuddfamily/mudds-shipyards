"""Validate the confidence grades in the station topology document.

The station floor plan is intentionally a set of bounded interpretations, not
one recovered historical map.  This small, dependency-free gate checks the
per-relationship Markdown tables without trying to authenticate the source
material.  It protects the important boundary:

* ``observed`` and ``fixed-era-inspired`` rows need a registered source anchor;
* ``new`` and ``unknown`` rows must explicitly have no source anchor;
* ``inferred`` rows may have an anchor or remain unanchored, but are never
  silently treated as observations.

The optional source ledger check only verifies that an anchor names a source
with at least one registered ledger anchor.  It deliberately does not parse
the prose timestamp into a claim or promote a live implementation.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


LABELS = frozenset({"observed", "inferred", "fixed-era-inspired", "new", "unknown"})
ANCHOR_REQUIRED_LABELS = frozenset({"observed", "fixed-era-inspired"})
ANCHOR_FORBIDDEN_LABELS = frozenset({"new", "unknown"})
EXPECTED_FAMILIES = frozenset(
    {
        "Habitat relationships",
        "VIP relationships",
        "Platform and elevation relationships",
        "Ladder relationships",
        "Regeneration relationships",
        "Dock-arm relationships",
        "Room relationships",
    }
)
TABLE_HEADER = (
    "Relationship",
    "Live implementation",
    "Label",
    "Evidence anchor",
    "Status",
    "Unknowns",
)
SOURCE_ID_PATTERN = re.compile(r"\b[A-Z]\d+\b")
LABEL_TOKEN_PATTERN = re.compile(
    r"(?<![A-Za-z])(?:observed|inferred|fixed-era-inspired|new|unknown)(?![A-Za-z])"
)
FAMILY_HEADING_PATTERN = re.compile(r"^###\s+(.+\s+relationships)\s*$")
NO_ANCHOR_PREFIXES = ("none", "unknown", "n/a", "na", "not available", "—", "-")


@dataclass(frozen=True)
class ConfidenceRow:
    family: str
    relationship: str
    live_implementation: str
    label: str
    evidence_anchor: str
    status: str
    unknowns: str
    line_number: int


def _split_table_row(line: str) -> tuple[str, ...]:
    """Split one simple Markdown table row, retaining empty cells."""

    stripped = line.strip()
    if not stripped.startswith("|"):
        return ()
    cells = stripped.strip("|").split("|")
    return tuple(cell.strip() for cell in cells)


def _is_separator(cells: tuple[str, ...]) -> bool:
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def _is_missing_anchor(value: str) -> bool:
    normalized = value.strip().lower()
    if not normalized:
        return True
    return normalized.startswith(NO_ANCHOR_PREFIXES)


def _source_ids(value: str) -> tuple[str, ...]:
    return tuple(dict.fromkeys(SOURCE_ID_PATTERN.findall(value)))


def _labels(value: str) -> tuple[str, ...]:
    """Return the one or more labels used by a grading cell.

    The document has two deliberately compound rows (for example, a habitat
    room is fixed-era-inspired for one motif and new for its authored plan).
    Keeping those distinctions in one cell is useful, so the validator accepts
    a leading allowed label followed by explanatory prose and/or another
    allowed label.
    """

    tokens = tuple(dict.fromkeys(LABEL_TOKEN_PATTERN.findall(value)))
    if not tokens:
        return (value.strip(),) if value.strip() else ()
    if value.strip() == tokens[0] or value.strip().startswith(tokens[0]):
        return tokens
    return (value.strip(),)


def _read_anchored_sources(ledger_path: str | Path | None) -> tuple[set[str], set[str]]:
    if ledger_path is None:
        return set(), set()
    path = Path(ledger_path)
    payload = json.loads(path.read_text(encoding="utf-8"))
    anchored: set[str] = set()
    all_sources: set[str] = set()
    for source in payload.get("sources", []):
        source_id = source.get("id")
        if not isinstance(source_id, str):
            continue
        all_sources.add(source_id)
        if source.get("anchors"):
            anchored.add(source_id)
    return all_sources, anchored


def parse_confidence_rows(text: str) -> tuple[tuple[ConfidenceRow, ...], list[str]]:
    """Parse the seven per-relationship tables from topology Markdown."""

    lines = text.splitlines()
    rows: list[ConfidenceRow] = []
    errors: list[str] = []
    families_seen: set[str] = set()
    current_family: str | None = None
    family_table_seen: set[str] = set()
    index = 0
    while index < len(lines):
        heading = FAMILY_HEADING_PATTERN.match(lines[index].strip())
        if heading:
            current_family = heading.group(1).strip()
            families_seen.add(current_family)
            index += 1
            continue

        header = _split_table_row(lines[index])
        if header != TABLE_HEADER:
            index += 1
            continue
        if current_family is None:
            errors.append(f"line {index + 1}: confidence table is outside a family heading")
            index += 1
            continue
        family_table_seen.add(current_family)
        if index + 1 >= len(lines) or not _is_separator(_split_table_row(lines[index + 1])):
            errors.append(f"line {index + 1}: confidence table has no Markdown separator")
            index += 1
            continue
        index += 2
        while index < len(lines):
            cells = _split_table_row(lines[index])
            if not cells:
                break
            if len(cells) != len(TABLE_HEADER):
                errors.append(f"line {index + 1}: confidence row has {len(cells)} cells, expected 6")
            else:
                rows.append(
                    ConfidenceRow(
                        family=current_family,
                        relationship=cells[0],
                        live_implementation=cells[1],
                        label=cells[2],
                        evidence_anchor=cells[3],
                        status=cells[4],
                        unknowns=cells[5],
                        line_number=index + 1,
                    )
                )
            index += 1

    missing_families = sorted(EXPECTED_FAMILIES - families_seen)
    for family in missing_families:
        errors.append(f"missing confidence family heading: {family}")
    for family in sorted(EXPECTED_FAMILIES & families_seen):
        if family not in family_table_seen:
            errors.append(f"missing confidence table: {family}")
    if not rows:
        errors.append("no per-relationship confidence rows found")
    return tuple(rows), errors


def validate_rows(
    rows: Iterable[ConfidenceRow],
    *,
    ledger_path: str | Path | None = None,
) -> list[str]:
    """Validate parsed confidence rows and their evidence boundaries."""

    errors: list[str] = []
    all_sources, anchored_sources = _read_anchored_sources(ledger_path)
    seen_relationships: set[str] = set()
    labels_seen: set[str] = set()
    for row in rows:
        prefix = f"line {row.line_number} ({row.family}/{row.relationship})"
        relationship_key = row.relationship.casefold()
        if not row.relationship:
            errors.append(f"{prefix}: relationship is empty")
        elif relationship_key in seen_relationships:
            errors.append(f"{prefix}: duplicate relationship")
        seen_relationships.add(relationship_key)

        row_labels = _labels(row.label)
        if not row_labels or any(label not in LABELS for label in row_labels):
            errors.append(f"{prefix}: invalid label {row.label.strip()!r}; expected one of {sorted(LABELS)}")
            row_labels = ()
        labels_seen.update(row_labels)
        if not row.live_implementation.strip():
            errors.append(f"{prefix}: live implementation is empty")
        if not row.status.strip():
            errors.append(f"{prefix}: status is empty")
        if not row.unknowns.strip():
            errors.append(f"{prefix}: unknowns must be explicit")

        anchor = row.evidence_anchor.strip()
        missing_anchor = _is_missing_anchor(anchor)
        source_ids = _source_ids(anchor)
        requires_anchor = bool(set(row_labels) & ANCHOR_REQUIRED_LABELS)
        forbids_anchor = bool(row_labels) and set(row_labels).issubset(ANCHOR_FORBIDDEN_LABELS)
        if requires_anchor:
            if missing_anchor or not source_ids:
                errors.append(f"{prefix}: {', '.join(sorted(set(row_labels) & ANCHOR_REQUIRED_LABELS))} requires a registered source anchor")
            if ledger_path is not None and source_ids:
                unknown_sources = sorted(set(source_ids) - all_sources)
                if unknown_sources:
                    errors.append(f"{prefix}: anchor names unregistered source(s): {', '.join(unknown_sources)}")
                elif not (set(source_ids) & anchored_sources):
                    errors.append(f"{prefix}: anchor names no source with a registered ledger anchor")
        elif forbids_anchor:
            if not missing_anchor or source_ids:
                errors.append(f"{prefix}: {', '.join(sorted(set(row_labels)))} must use an explicit no-anchor marker")
            if "new" in row_labels and "modern_interpretation" not in row.status.casefold():
                errors.append(f"{prefix}: new relationship must remain modern_interpretation")
            if "unknown" in row_labels and "unknown" not in row.status.casefold():
                errors.append(f"{prefix}: unknown relationship must retain unknown status")
        elif "inferred" in row_labels:
            # An inferred row may cite a source or explicitly remain unanchored;
            # either way its label is the boundary that prevents promotion.
            if "authenticated" in row.status.casefold():
                errors.append(f"{prefix}: inferred relationship cannot be authenticated")

    missing_labels = sorted(LABELS - labels_seen)
    for label in missing_labels:
        errors.append(f"confidence tables do not exercise label: {label}")
    return errors


def validate_topology(
    topology_path: str | Path,
    *,
    ledger_path: str | Path | None = None,
) -> list[str]:
    """Return fail-closed errors for a confidence-graded topology document."""

    path = Path(topology_path)
    if ledger_path is None:
        candidate = path.with_name("source_ledger.json")
        if candidate.exists():
            ledger_path = candidate
        else:
            repository_candidate = path.parents[1] / "source_ledger.json"
            if repository_candidate.exists():
                ledger_path = repository_candidate
    rows, errors = parse_confidence_rows(path.read_text(encoding="utf-8"))
    errors.extend(validate_rows(rows, ledger_path=ledger_path))
    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    errors = validate_topology(
        root / "docs/research/STATION_TOPOLOGY.md",
        ledger_path=root / "docs/research/source_ledger.json",
    )
    if errors:
        print("STATION_ROUTE_CONFIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("STATION_ROUTE_CONFIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
