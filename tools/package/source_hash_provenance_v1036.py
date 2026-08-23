"""Schema-1036 source provenance validator."""


def validate_v1036(value, label="source_provenance_v1036"):
    """Return schema errors for a v1036 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1036:
        return [f"{label}.schema_version must be 1036"]
    return []
