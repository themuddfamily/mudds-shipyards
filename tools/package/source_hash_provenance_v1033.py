"""Schema-1033 source provenance validator."""


def validate_v1033(value, label="source_provenance_v1033"):
    """Return schema errors for a v1033 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1033:
        return [f"{label}.schema_version must be 1033"]
    return []
