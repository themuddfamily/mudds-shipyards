"""Schema-983 source provenance validator."""


def validate_v983(value, label="source_provenance_v983"):
    """Return schema errors for a v983 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 983:
        return [f"{label}.schema_version must be 983"]
    return []
