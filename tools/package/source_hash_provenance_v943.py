"""Schema-943 source provenance validator."""


def validate_v943(value, label="source_provenance_v943"):
    """Return schema errors for a v943 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 943:
        return [f"{label}.schema_version must be 943"]
    return []
