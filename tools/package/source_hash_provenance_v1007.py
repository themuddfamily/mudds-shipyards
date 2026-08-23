"""Schema-1007 source provenance validator."""


def validate_v1007(value, label="source_provenance_v1007"):
    """Return schema errors for a v1007 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1007:
        return [f"{label}.schema_version must be 1007"]
    return []
