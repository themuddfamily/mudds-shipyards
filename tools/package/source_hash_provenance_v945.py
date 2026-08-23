"""Schema-945 source provenance validator."""


def validate_v945(value, label="source_provenance_v945"):
    """Return schema errors for a v945 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 945:
        return [f"{label}.schema_version must be 945"]
    return []
