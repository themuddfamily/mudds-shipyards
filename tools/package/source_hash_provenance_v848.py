"""Schema-848 source provenance validator."""


def validate_v848(value, label="source_provenance_v848"):
    """Return schema errors for a v848 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 848:
        return [f"{label}.schema_version must be 848"]
    return []
