"""Schema-941 source provenance validator."""


def validate_v941(value, label="source_provenance_v941"):
    """Return schema errors for a v941 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 941:
        return [f"{label}.schema_version must be 941"]
    return []
