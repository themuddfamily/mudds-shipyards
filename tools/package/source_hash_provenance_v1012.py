"""Schema-1012 source provenance validator."""


def validate_v1012(value, label="source_provenance_v1012"):
    """Return schema errors for a v1012 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1012:
        return [f"{label}.schema_version must be 1012"]
    return []
