"""Schema-930 source provenance validator."""


def validate_v930(value, label="source_provenance_v930"):
    """Return schema errors for a v930 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 930:
        return [f"{label}.schema_version must be 930"]
    return []
