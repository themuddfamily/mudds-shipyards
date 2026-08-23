"""Schema-892 source provenance validator."""


def validate_v892(value, label="source_provenance_v892"):
    """Return schema errors for a v892 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 892:
        return [f"{label}.schema_version must be 892"]
    return []
