"""Schema-976 source provenance validator."""


def validate_v976(value, label="source_provenance_v976"):
    """Return schema errors for a v976 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 976:
        return [f"{label}.schema_version must be 976"]
    return []
