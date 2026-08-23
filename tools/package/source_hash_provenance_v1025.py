"""Schema-1025 source provenance validator."""


def validate_v1025(value, label="source_provenance_v1025"):
    """Return schema errors for a v1025 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1025:
        return [f"{label}.schema_version must be 1025"]
    return []
