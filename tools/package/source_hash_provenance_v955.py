"""Schema-955 source provenance validator."""


def validate_v955(value, label="source_provenance_v955"):
    """Return schema errors for a v955 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 955:
        return [f"{label}.schema_version must be 955"]
    return []
