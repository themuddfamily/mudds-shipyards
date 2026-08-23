"""Schema-936 source provenance validator."""


def validate_v936(value, label="source_provenance_v936"):
    """Return schema errors for a v936 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 936:
        return [f"{label}.schema_version must be 936"]
    return []
