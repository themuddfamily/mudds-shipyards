"""Schema-1031 source provenance validator."""


def validate_v1031(value, label="source_provenance_v1031"):
    """Return schema errors for a v1031 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1031:
        return [f"{label}.schema_version must be 1031"]
    return []
