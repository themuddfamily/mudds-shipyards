"""Schema-811 source provenance validator."""


def validate_v811(value, label="source_provenance_v811"):
    """Return schema errors for a v811 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 811:
        return [f"{label}.schema_version must be 811"]
    return []
