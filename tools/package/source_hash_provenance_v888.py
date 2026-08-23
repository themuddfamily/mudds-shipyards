"""Schema-888 source provenance validator."""


def validate_v888(value, label="source_provenance_v888"):
    """Return schema errors for a v888 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 888:
        return [f"{label}.schema_version must be 888"]
    return []
