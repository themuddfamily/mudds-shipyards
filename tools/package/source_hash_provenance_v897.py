"""Schema-897 source provenance validator."""


def validate_v897(value, label="source_provenance_v897"):
    """Return schema errors for a v897 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 897:
        return [f"{label}.schema_version must be 897"]
    return []
