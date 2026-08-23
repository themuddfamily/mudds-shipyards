"""Schema-910 source provenance validator."""


def validate_v910(value, label="source_provenance_v910"):
    """Return schema errors for a v910 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 910:
        return [f"{label}.schema_version must be 910"]
    return []
