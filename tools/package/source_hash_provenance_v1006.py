"""Schema-1006 source provenance validator."""


def validate_v1006(value, label="source_provenance_v1006"):
    """Return schema errors for a v1006 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1006:
        return [f"{label}.schema_version must be 1006"]
    return []
