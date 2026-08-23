"""Schema-821 source provenance validator."""


def validate_v821(value, label="source_provenance_v821"):
    """Return schema errors for a v821 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 821:
        return [f"{label}.schema_version must be 821"]
    return []
