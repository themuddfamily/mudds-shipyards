"""Schema-1018 source provenance validator."""


def validate_v1018(value, label="source_provenance_v1018"):
    """Return schema errors for a v1018 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1018:
        return [f"{label}.schema_version must be 1018"]
    return []
