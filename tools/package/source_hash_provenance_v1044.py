"""Schema-1044 source provenance validator."""


def validate_v1044(value, label="source_provenance_v1044"):
    """Return schema errors for a v1044 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1044:
        return [f"{label}.schema_version must be 1044"]
    return []
