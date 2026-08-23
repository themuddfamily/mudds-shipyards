"""Schema-844 source provenance validator."""


def validate_v844(value, label="source_provenance_v844"):
    """Return schema errors for a v844 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 844:
        return [f"{label}.schema_version must be 844"]
    return []
