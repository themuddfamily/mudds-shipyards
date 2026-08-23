"""Schema-1045 source provenance validator."""


def validate_v1045(value, label="source_provenance_v1045"):
    """Return schema errors for a v1045 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1045:
        return [f"{label}.schema_version must be 1045"]
    return []
