"""Schema-989 source provenance validator."""


def validate_v989(value, label="source_provenance_v989"):
    """Return schema errors for a v989 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 989:
        return [f"{label}.schema_version must be 989"]
    return []
