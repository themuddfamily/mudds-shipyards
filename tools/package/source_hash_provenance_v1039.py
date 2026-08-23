"""Schema-1039 source provenance validator."""


def validate_v1039(value, label="source_provenance_v1039"):
    """Return schema errors for a v1039 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1039:
        return [f"{label}.schema_version must be 1039"]
    return []
