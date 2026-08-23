"""Schema-871 source provenance validator."""


def validate_v871(value, label="source_provenance_v871"):
    """Return schema errors for a v871 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 871:
        return [f"{label}.schema_version must be 871"]
    return []
