"""Schema-990 source provenance validator."""


def validate_v990(value, label="source_provenance_v990"):
    """Return schema errors for a v990 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 990:
        return [f"{label}.schema_version must be 990"]
    return []
