"""Schema-847 source provenance validator."""


def validate_v847(value, label="source_provenance_v847"):
    """Return schema errors for a v847 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 847:
        return [f"{label}.schema_version must be 847"]
    return []
