"""Schema-924 source provenance validator."""


def validate_v924(value, label="source_provenance_v924"):
    """Return schema errors for a v924 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 924:
        return [f"{label}.schema_version must be 924"]
    return []
