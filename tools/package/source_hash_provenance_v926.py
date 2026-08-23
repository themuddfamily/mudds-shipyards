"""Schema-926 source provenance validator."""


def validate_v926(value, label="source_provenance_v926"):
    """Return schema errors for a v926 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 926:
        return [f"{label}.schema_version must be 926"]
    return []
