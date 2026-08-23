"""Schema-973 source provenance validator."""


def validate_v973(value, label="source_provenance_v973"):
    """Return schema errors for a v973 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 973:
        return [f"{label}.schema_version must be 973"]
    return []
