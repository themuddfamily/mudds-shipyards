"""Schema-845 source provenance validator."""


def validate_v845(value, label="source_provenance_v845"):
    """Return schema errors for a v845 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 845:
        return [f"{label}.schema_version must be 845"]
    return []
