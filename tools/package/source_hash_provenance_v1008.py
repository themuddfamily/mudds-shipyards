"""Schema-1008 source provenance validator."""


def validate_v1008(value, label="source_provenance_v1008"):
    """Return schema errors for a v1008 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1008:
        return [f"{label}.schema_version must be 1008"]
    return []
