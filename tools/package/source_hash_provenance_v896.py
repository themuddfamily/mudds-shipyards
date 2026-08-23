"""Schema-896 source provenance validator."""


def validate_v896(value, label="source_provenance_v896"):
    """Return schema errors for a v896 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 896:
        return [f"{label}.schema_version must be 896"]
    return []
