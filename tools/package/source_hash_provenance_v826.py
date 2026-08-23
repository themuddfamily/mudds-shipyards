"""Schema-826 source provenance validator."""


def validate_v826(value, label="source_provenance_v826"):
    """Return schema errors for a v826 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 826:
        return [f"{label}.schema_version must be 826"]
    return []
