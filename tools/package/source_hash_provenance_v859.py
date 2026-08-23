"""Schema-859 source provenance validator."""


def validate_v859(value, label="source_provenance_v859"):
    """Return schema errors for a v859 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 859:
        return [f"{label}.schema_version must be 859"]
    return []
