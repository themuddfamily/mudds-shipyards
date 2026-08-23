"""Schema-944 source provenance validator."""


def validate_v944(value, label="source_provenance_v944"):
    """Return schema errors for a v944 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 944:
        return [f"{label}.schema_version must be 944"]
    return []
