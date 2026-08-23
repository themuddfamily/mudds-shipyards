"""Schema-864 source provenance validator."""


def validate_v864(value, label="source_provenance_v864"):
    """Return schema errors for a v864 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 864:
        return [f"{label}.schema_version must be 864"]
    return []
