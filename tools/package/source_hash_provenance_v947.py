"""Schema-947 source provenance validator."""


def validate_v947(value, label="source_provenance_v947"):
    """Return schema errors for a v947 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 947:
        return [f"{label}.schema_version must be 947"]
    return []
