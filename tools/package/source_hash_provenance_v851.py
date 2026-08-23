"""Schema-851 source provenance validator."""


def validate_v851(value, label="source_provenance_v851"):
    """Return schema errors for a v851 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 851:
        return [f"{label}.schema_version must be 851"]
    return []
