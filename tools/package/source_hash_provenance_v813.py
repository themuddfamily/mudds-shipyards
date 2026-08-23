"""Schema-813 source provenance validator."""


def validate_v813(value, label="source_provenance_v813"):
    """Return schema errors for a v813 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 813:
        return [f"{label}.schema_version must be 813"]
    return []
