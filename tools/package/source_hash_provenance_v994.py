"""Schema-994 source provenance validator."""


def validate_v994(value, label="source_provenance_v994"):
    """Return schema errors for a v994 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 994:
        return [f"{label}.schema_version must be 994"]
    return []
