"""Schema-962 source provenance validator."""


def validate_v962(value, label="source_provenance_v962"):
    """Return schema errors for a v962 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 962:
        return [f"{label}.schema_version must be 962"]
    return []
