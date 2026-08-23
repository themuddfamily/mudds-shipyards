"""Schema-908 source provenance validator."""


def validate_v908(value, label="source_provenance_v908"):
    """Return schema errors for a v908 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 908:
        return [f"{label}.schema_version must be 908"]
    return []
