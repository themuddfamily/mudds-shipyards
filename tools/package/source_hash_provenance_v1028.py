"""Schema-1028 source provenance validator."""


def validate_v1028(value, label="source_provenance_v1028"):
    """Return schema errors for a v1028 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1028:
        return [f"{label}.schema_version must be 1028"]
    return []
