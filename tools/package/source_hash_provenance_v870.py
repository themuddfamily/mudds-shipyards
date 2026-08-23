"""Schema-870 source provenance validator."""


def validate_v870(value, label="source_provenance_v870"):
    """Return schema errors for a v870 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 870:
        return [f"{label}.schema_version must be 870"]
    return []
