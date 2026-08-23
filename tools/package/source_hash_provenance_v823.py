"""Schema-823 source provenance validator."""


def validate_v823(value, label="source_provenance_v823"):
    """Return schema errors for a v823 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 823:
        return [f"{label}.schema_version must be 823"]
    return []
