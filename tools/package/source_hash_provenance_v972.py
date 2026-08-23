"""Schema-972 source provenance validator."""


def validate_v972(value, label="source_provenance_v972"):
    """Return schema errors for a v972 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 972:
        return [f"{label}.schema_version must be 972"]
    return []
