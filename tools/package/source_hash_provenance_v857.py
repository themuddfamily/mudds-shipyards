"""Schema-857 source provenance validator."""


def validate_v857(value, label="source_provenance_v857"):
    """Return schema errors for a v857 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 857:
        return [f"{label}.schema_version must be 857"]
    return []
