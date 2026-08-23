"""Schema-1029 source provenance validator."""


def validate_v1029(value, label="source_provenance_v1029"):
    """Return schema errors for a v1029 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1029:
        return [f"{label}.schema_version must be 1029"]
    return []
