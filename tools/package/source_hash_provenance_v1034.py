"""Schema-1034 source provenance validator."""


def validate_v1034(value, label="source_provenance_v1034"):
    """Return schema errors for a v1034 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1034:
        return [f"{label}.schema_version must be 1034"]
    return []
