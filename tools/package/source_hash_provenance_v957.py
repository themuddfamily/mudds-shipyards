"""Schema-957 source provenance validator."""


def validate_v957(value, label="source_provenance_v957"):
    """Return schema errors for a v957 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 957:
        return [f"{label}.schema_version must be 957"]
    return []
