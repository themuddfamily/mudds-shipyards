"""Schema-1026 source provenance validator."""


def validate_v1026(value, label="source_provenance_v1026"):
    """Return schema errors for a v1026 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1026:
        return [f"{label}.schema_version must be 1026"]
    return []
