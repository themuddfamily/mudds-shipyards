"""Schema-949 source provenance validator."""


def validate_v949(value, label="source_provenance_v949"):
    """Return schema errors for a v949 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 949:
        return [f"{label}.schema_version must be 949"]
    return []
