"""Schema-835 source provenance validator."""


def validate_v835(value, label="source_provenance_v835"):
    """Return schema errors for a v835 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 835:
        return [f"{label}.schema_version must be 835"]
    return []
