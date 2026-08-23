"""Schema-992 source provenance validator."""


def validate_v992(value, label="source_provenance_v992"):
    """Return schema errors for a v992 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 992:
        return [f"{label}.schema_version must be 992"]
    return []
