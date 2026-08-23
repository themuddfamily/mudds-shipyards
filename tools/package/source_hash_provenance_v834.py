"""Schema-834 source provenance validator."""


def validate_v834(value, label="source_provenance_v834"):
    """Return schema errors for a v834 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 834:
        return [f"{label}.schema_version must be 834"]
    return []
