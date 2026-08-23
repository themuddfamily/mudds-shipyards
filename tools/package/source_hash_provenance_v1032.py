"""Schema-1032 source provenance validator."""


def validate_v1032(value, label="source_provenance_v1032"):
    """Return schema errors for a v1032 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1032:
        return [f"{label}.schema_version must be 1032"]
    return []
