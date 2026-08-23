"""Schema-842 source provenance validator."""


def validate_v842(value, label="source_provenance_v842"):
    """Return schema errors for a v842 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 842:
        return [f"{label}.schema_version must be 842"]
    return []
