"""Schema-819 source provenance validator."""


def validate_v819(value, label="source_provenance_v819"):
    """Return schema errors for a v819 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 819:
        return [f"{label}.schema_version must be 819"]
    return []
