"""Schema-895 source provenance validator."""


def validate_v895(value, label="source_provenance_v895"):
    """Return schema errors for a v895 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 895:
        return [f"{label}.schema_version must be 895"]
    return []
