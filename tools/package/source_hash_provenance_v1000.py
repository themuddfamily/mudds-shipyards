"""Schema-1000 source provenance validator."""


def validate_v1000(value, label="source_provenance_v1000"):
    """Return schema errors for a v1000 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1000:
        return [f"{label}.schema_version must be 1000"]
    return []
