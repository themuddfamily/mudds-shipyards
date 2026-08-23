"""Schema-1027 source provenance validator."""


def validate_v1027(value, label="source_provenance_v1027"):
    """Return schema errors for a v1027 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1027:
        return [f"{label}.schema_version must be 1027"]
    return []
