"""Schema-993 source provenance validator."""


def validate_v993(value, label="source_provenance_v993"):
    """Return schema errors for a v993 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 993:
        return [f"{label}.schema_version must be 993"]
    return []
