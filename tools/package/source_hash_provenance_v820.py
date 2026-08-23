"""Schema-820 source provenance validator."""


def validate_v820(value, label="source_provenance_v820"):
    """Return schema errors for a v820 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 820:
        return [f"{label}.schema_version must be 820"]
    return []
