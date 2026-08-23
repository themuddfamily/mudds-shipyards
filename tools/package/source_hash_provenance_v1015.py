"""Schema-1015 source provenance validator."""


def validate_v1015(value, label="source_provenance_v1015"):
    """Return schema errors for a v1015 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1015:
        return [f"{label}.schema_version must be 1015"]
    return []
