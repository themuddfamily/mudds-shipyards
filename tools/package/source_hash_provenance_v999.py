"""Schema-999 source provenance validator."""


def validate_v999(value, label="source_provenance_v999"):
    """Return schema errors for a v999 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 999:
        return [f"{label}.schema_version must be 999"]
    return []
