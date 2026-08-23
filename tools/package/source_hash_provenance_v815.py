"""Schema-815 source provenance validator."""


def validate_v815(value, label="source_provenance_v815"):
    """Return schema errors for a v815 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 815:
        return [f"{label}.schema_version must be 815"]
    return []
