"""Schema-1030 source provenance validator."""


def validate_v1030(value, label="source_provenance_v1030"):
    """Return schema errors for a v1030 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1030:
        return [f"{label}.schema_version must be 1030"]
    return []
