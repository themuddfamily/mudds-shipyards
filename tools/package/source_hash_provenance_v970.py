"""Schema-970 source provenance validator."""


def validate_v970(value, label="source_provenance_v970"):
    """Return schema errors for a v970 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 970:
        return [f"{label}.schema_version must be 970"]
    return []
