"""Schema-861 source provenance validator."""


def validate_v861(value, label="source_provenance_v861"):
    """Return schema errors for a v861 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 861:
        return [f"{label}.schema_version must be 861"]
    return []
