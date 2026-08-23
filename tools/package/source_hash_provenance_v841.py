"""Schema-841 source provenance validator."""


def validate_v841(value, label="source_provenance_v841"):
    """Return schema errors for a v841 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 841:
        return [f"{label}.schema_version must be 841"]
    return []
