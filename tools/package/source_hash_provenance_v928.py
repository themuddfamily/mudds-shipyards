"""Schema-928 source provenance validator."""


def validate_v928(value, label="source_provenance_v928"):
    """Return schema errors for a v928 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 928:
        return [f"{label}.schema_version must be 928"]
    return []
