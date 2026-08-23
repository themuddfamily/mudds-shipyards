"""Schema-977 source provenance validator."""


def validate_v977(value, label="source_provenance_v977"):
    """Return schema errors for a v977 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 977:
        return [f"{label}.schema_version must be 977"]
    return []
