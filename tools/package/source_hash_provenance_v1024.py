"""Schema-1024 source provenance validator."""


def validate_v1024(value, label="source_provenance_v1024"):
    """Return schema errors for a v1024 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1024:
        return [f"{label}.schema_version must be 1024"]
    return []
