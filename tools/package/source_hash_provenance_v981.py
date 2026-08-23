"""Schema-981 source provenance validator."""


def validate_v981(value, label="source_provenance_v981"):
    """Return schema errors for a v981 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 981:
        return [f"{label}.schema_version must be 981"]
    return []
