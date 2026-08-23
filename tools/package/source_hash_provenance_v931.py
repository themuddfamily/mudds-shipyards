"""Schema-931 source provenance validator."""


def validate_v931(value, label="source_provenance_v931"):
    """Return schema errors for a v931 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 931:
        return [f"{label}.schema_version must be 931"]
    return []
