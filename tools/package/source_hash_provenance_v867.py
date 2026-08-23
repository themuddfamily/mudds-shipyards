"""Schema-867 source provenance validator."""


def validate_v867(value, label="source_provenance_v867"):
    """Return schema errors for a v867 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 867:
        return [f"{label}.schema_version must be 867"]
    return []
