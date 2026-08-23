"""Schema-816 source provenance validator."""


def validate_v816(value, label="source_provenance_v816"):
    """Return schema errors for a v816 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 816:
        return [f"{label}.schema_version must be 816"]
    return []
