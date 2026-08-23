"""Schema-887 source provenance validator."""


def validate_v887(value, label="source_provenance_v887"):
    """Return schema errors for a v887 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 887:
        return [f"{label}.schema_version must be 887"]
    return []
