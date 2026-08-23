"""Schema-969 source provenance validator."""


def validate_v969(value, label="source_provenance_v969"):
    """Return schema errors for a v969 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 969:
        return [f"{label}.schema_version must be 969"]
    return []
