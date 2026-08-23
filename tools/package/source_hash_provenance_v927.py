"""Schema-927 source provenance validator."""


def validate_v927(value, label="source_provenance_v927"):
    """Return schema errors for a v927 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 927:
        return [f"{label}.schema_version must be 927"]
    return []
