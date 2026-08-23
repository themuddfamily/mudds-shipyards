"""Schema-950 source provenance validator."""


def validate_v950(value, label="source_provenance_v950"):
    """Return schema errors for a v950 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 950:
        return [f"{label}.schema_version must be 950"]
    return []
