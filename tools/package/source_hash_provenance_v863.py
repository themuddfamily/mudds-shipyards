"""Schema-863 source provenance validator."""


def validate_v863(value, label="source_provenance_v863"):
    """Return schema errors for a v863 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 863:
        return [f"{label}.schema_version must be 863"]
    return []
