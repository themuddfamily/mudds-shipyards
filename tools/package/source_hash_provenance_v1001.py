"""Schema-1001 source provenance validator."""


def validate_v1001(value, label="source_provenance_v1001"):
    """Return schema errors for a v1001 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1001:
        return [f"{label}.schema_version must be 1001"]
    return []
