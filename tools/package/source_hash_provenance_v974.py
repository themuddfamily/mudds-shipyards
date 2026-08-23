"""Schema-974 source provenance validator."""


def validate_v974(value, label="source_provenance_v974"):
    """Return schema errors for a v974 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 974:
        return [f"{label}.schema_version must be 974"]
    return []
