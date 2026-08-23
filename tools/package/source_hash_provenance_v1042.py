"""Schema-1042 source provenance validator."""


def validate_v1042(value, label="source_provenance_v1042"):
    """Return schema errors for a v1042 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1042:
        return [f"{label}.schema_version must be 1042"]
    return []
