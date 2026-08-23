"""Schema-837 source provenance validator."""


def validate_v837(value, label="source_provenance_v837"):
    """Return schema errors for a v837 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 837:
        return [f"{label}.schema_version must be 837"]
    return []
