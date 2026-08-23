"""Schema-971 source provenance validator."""


def validate_v971(value, label="source_provenance_v971"):
    """Return schema errors for a v971 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 971:
        return [f"{label}.schema_version must be 971"]
    return []
