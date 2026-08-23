"""Schema-986 source provenance validator."""


def validate_v986(value, label="source_provenance_v986"):
    """Return schema errors for a v986 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 986:
        return [f"{label}.schema_version must be 986"]
    return []
