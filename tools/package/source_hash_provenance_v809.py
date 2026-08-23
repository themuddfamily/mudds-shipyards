"""Schema-809 source provenance validator."""


def validate_v809(value, label="source_provenance_v809"):
    """Return schema errors for a v809 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 809:
        return [f"{label}.schema_version must be 809"]
    return []
