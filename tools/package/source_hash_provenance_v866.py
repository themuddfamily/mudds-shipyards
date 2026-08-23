"""Schema-866 source provenance validator."""


def validate_v866(value, label="source_provenance_v866"):
    """Return schema errors for a v866 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 866:
        return [f"{label}.schema_version must be 866"]
    return []
