"""Schema-958 source provenance validator."""


def validate_v958(value, label="source_provenance_v958"):
    """Return schema errors for a v958 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 958:
        return [f"{label}.schema_version must be 958"]
    return []
