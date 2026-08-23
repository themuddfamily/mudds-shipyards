"""Schema-942 source provenance validator."""


def validate_v942(value, label="source_provenance_v942"):
    """Return schema errors for a v942 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 942:
        return [f"{label}.schema_version must be 942"]
    return []
