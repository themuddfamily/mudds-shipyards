"""Schema-1010 source provenance validator."""


def validate_v1010(value, label="source_provenance_v1010"):
    """Return schema errors for a v1010 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1010:
        return [f"{label}.schema_version must be 1010"]
    return []
