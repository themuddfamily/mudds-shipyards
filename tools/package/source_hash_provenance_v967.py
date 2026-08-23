"""Schema-967 source provenance validator."""


def validate_v967(value, label="source_provenance_v967"):
    """Return schema errors for a v967 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 967:
        return [f"{label}.schema_version must be 967"]
    return []
