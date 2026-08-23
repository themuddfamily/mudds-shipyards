"""Schema-843 source provenance validator."""


def validate_v843(value, label="source_provenance_v843"):
    """Return schema errors for a v843 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 843:
        return [f"{label}.schema_version must be 843"]
    return []
