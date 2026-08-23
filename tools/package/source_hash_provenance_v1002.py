"""Schema-1002 source provenance validator."""


def validate_v1002(value, label="source_provenance_v1002"):
    """Return schema errors for a v1002 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1002:
        return [f"{label}.schema_version must be 1002"]
    return []
