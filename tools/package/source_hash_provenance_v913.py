"""Schema-913 source provenance validator."""


def validate_v913(value, label="source_provenance_v913"):
    """Return schema errors for a v913 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 913:
        return [f"{label}.schema_version must be 913"]
    return []
