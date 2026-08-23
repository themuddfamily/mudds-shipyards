"""Schema-1009 source provenance validator."""


def validate_v1009(value, label="source_provenance_v1009"):
    """Return schema errors for a v1009 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1009:
        return [f"{label}.schema_version must be 1009"]
    return []
