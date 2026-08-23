"""Schema-909 source provenance validator."""


def validate_v909(value, label="source_provenance_v909"):
    """Return schema errors for a v909 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 909:
        return [f"{label}.schema_version must be 909"]
    return []
