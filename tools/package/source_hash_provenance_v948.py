"""Schema-948 source provenance validator."""


def validate_v948(value, label="source_provenance_v948"):
    """Return schema errors for a v948 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 948:
        return [f"{label}.schema_version must be 948"]
    return []
