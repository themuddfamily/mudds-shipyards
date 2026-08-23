"""Schema-998 source provenance validator."""


def validate_v998(value, label="source_provenance_v998"):
    """Return schema errors for a v998 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 998:
        return [f"{label}.schema_version must be 998"]
    return []
