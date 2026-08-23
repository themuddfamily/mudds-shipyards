"""Schema-884 source provenance validator."""


def validate_v884(value, label="source_provenance_v884"):
    """Return schema errors for a v884 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 884:
        return [f"{label}.schema_version must be 884"]
    return []
