"""Schema-934 source provenance validator."""


def validate_v934(value, label="source_provenance_v934"):
    """Return schema errors for a v934 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 934:
        return [f"{label}.schema_version must be 934"]
    return []
