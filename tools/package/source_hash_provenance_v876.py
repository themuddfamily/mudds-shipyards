"""Schema-876 source provenance validator."""


def validate_v876(value, label="source_provenance_v876"):
    """Return schema errors for a v876 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 876:
        return [f"{label}.schema_version must be 876"]
    return []
