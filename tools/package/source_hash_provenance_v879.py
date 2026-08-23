"""Schema-879 source provenance validator."""


def validate_v879(value, label="source_provenance_v879"):
    """Return schema errors for a v879 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 879:
        return [f"{label}.schema_version must be 879"]
    return []
