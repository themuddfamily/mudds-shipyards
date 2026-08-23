"""Schema-938 source provenance validator."""


def validate_v938(value, label="source_provenance_v938"):
    """Return schema errors for a v938 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 938:
        return [f"{label}.schema_version must be 938"]
    return []
