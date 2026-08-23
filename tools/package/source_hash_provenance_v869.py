"""Schema-869 source provenance validator."""


def validate_v869(value, label="source_provenance_v869"):
    """Return schema errors for a v869 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 869:
        return [f"{label}.schema_version must be 869"]
    return []
