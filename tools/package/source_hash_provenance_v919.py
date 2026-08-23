"""Schema-919 source provenance validator."""


def validate_v919(value, label="source_provenance_v919"):
    """Return schema errors for a v919 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 919:
        return [f"{label}.schema_version must be 919"]
    return []
