"""Schema-825 source provenance validator."""


def validate_v825(value, label="source_provenance_v825"):
    """Return schema errors for a v825 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 825:
        return [f"{label}.schema_version must be 825"]
    return []
