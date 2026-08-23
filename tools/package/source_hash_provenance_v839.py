"""Schema-839 source provenance validator."""


def validate_v839(value, label="source_provenance_v839"):
    """Return schema errors for a v839 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 839:
        return [f"{label}.schema_version must be 839"]
    return []
