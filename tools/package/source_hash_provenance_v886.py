"""Schema-886 source provenance validator."""


def validate_v886(value, label="source_provenance_v886"):
    """Return schema errors for a v886 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 886:
        return [f"{label}.schema_version must be 886"]
    return []
