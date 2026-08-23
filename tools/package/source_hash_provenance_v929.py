"""Schema-929 source provenance validator."""


def validate_v929(value, label="source_provenance_v929"):
    """Return schema errors for a v929 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 929:
        return [f"{label}.schema_version must be 929"]
    return []
