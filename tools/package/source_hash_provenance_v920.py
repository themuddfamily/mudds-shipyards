"""Schema-920 source provenance validator."""


def validate_v920(value, label="source_provenance_v920"):
    """Return schema errors for a v920 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 920:
        return [f"{label}.schema_version must be 920"]
    return []
