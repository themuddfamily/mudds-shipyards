"""Schema-898 source provenance validator."""


def validate_v898(value, label="source_provenance_v898"):
    """Return schema errors for a v898 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 898:
        return [f"{label}.schema_version must be 898"]
    return []
