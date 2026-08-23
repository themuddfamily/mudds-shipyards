"""Schema-853 source provenance validator."""


def validate_v853(value, label="source_provenance_v853"):
    """Return schema errors for a v853 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 853:
        return [f"{label}.schema_version must be 853"]
    return []
