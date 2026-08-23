"""Schema-951 source provenance validator."""


def validate_v951(value, label="source_provenance_v951"):
    """Return schema errors for a v951 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 951:
        return [f"{label}.schema_version must be 951"]
    return []
