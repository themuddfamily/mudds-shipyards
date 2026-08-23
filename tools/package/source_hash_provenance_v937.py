"""Schema-937 source provenance validator."""


def validate_v937(value, label="source_provenance_v937"):
    """Return schema errors for a v937 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 937:
        return [f"{label}.schema_version must be 937"]
    return []
