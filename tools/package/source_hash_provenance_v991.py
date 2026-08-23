"""Schema-991 source provenance validator."""


def validate_v991(value, label="source_provenance_v991"):
    """Return schema errors for a v991 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 991:
        return [f"{label}.schema_version must be 991"]
    return []
