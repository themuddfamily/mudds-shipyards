"""Schema-827 source provenance validator."""


def validate_v827(value, label="source_provenance_v827"):
    """Return schema errors for a v827 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 827:
        return [f"{label}.schema_version must be 827"]
    return []
