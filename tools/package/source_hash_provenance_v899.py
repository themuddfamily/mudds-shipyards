"""Schema-899 source provenance validator."""


def validate_v899(value, label="source_provenance_v899"):
    """Return schema errors for a v899 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 899:
        return [f"{label}.schema_version must be 899"]
    return []
