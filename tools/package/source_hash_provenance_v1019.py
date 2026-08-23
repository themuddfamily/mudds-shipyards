"""Schema-1019 source provenance validator."""


def validate_v1019(value, label="source_provenance_v1019"):
    """Return schema errors for a v1019 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1019:
        return [f"{label}.schema_version must be 1019"]
    return []
