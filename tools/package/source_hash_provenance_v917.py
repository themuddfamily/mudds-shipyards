"""Schema-917 source provenance validator."""


def validate_v917(value, label="source_provenance_v917"):
    """Return schema errors for a v917 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 917:
        return [f"{label}.schema_version must be 917"]
    return []
