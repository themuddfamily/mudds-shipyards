"""Schema-965 source provenance validator."""


def validate_v965(value, label="source_provenance_v965"):
    """Return schema errors for a v965 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 965:
        return [f"{label}.schema_version must be 965"]
    return []
