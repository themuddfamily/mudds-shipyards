"""Schema-922 source provenance validator."""


def validate_v922(value, label="source_provenance_v922"):
    """Return schema errors for a v922 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 922:
        return [f"{label}.schema_version must be 922"]
    return []
