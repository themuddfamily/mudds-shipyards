"""Schema-960 source provenance validator."""


def validate_v960(value, label="source_provenance_v960"):
    """Return schema errors for a v960 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 960:
        return [f"{label}.schema_version must be 960"]
    return []
