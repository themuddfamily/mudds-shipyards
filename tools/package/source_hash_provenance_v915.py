"""Schema-915 source provenance validator."""


def validate_v915(value, label="source_provenance_v915"):
    """Return schema errors for a v915 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 915:
        return [f"{label}.schema_version must be 915"]
    return []
