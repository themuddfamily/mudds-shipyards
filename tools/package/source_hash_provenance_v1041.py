"""Schema-1041 source provenance validator."""


def validate_v1041(value, label="source_provenance_v1041"):
    """Return schema errors for a v1041 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1041:
        return [f"{label}.schema_version must be 1041"]
    return []
