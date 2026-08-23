"""Schema-1014 source provenance validator."""


def validate_v1014(value, label="source_provenance_v1014"):
    """Return schema errors for a v1014 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1014:
        return [f"{label}.schema_version must be 1014"]
    return []
