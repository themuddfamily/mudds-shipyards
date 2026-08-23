"""Schema-916 source provenance validator."""


def validate_v916(value, label="source_provenance_v916"):
    """Return schema errors for a v916 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 916:
        return [f"{label}.schema_version must be 916"]
    return []
