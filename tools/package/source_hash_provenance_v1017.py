"""Schema-1017 source provenance validator."""


def validate_v1017(value, label="source_provenance_v1017"):
    """Return schema errors for a v1017 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1017:
        return [f"{label}.schema_version must be 1017"]
    return []
