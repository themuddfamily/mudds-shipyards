"""Schema-900 source provenance validator."""


def validate_v900(value, label="source_provenance_v900"):
    """Return schema errors for a v900 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 900:
        return [f"{label}.schema_version must be 900"]
    return []
