"""Schema-1043 source provenance validator."""


def validate_v1043(value, label="source_provenance_v1043"):
    """Return schema errors for a v1043 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1043:
        return [f"{label}.schema_version must be 1043"]
    return []
