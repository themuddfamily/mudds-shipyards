"""Schema-902 source provenance validator."""


def validate_v902(value, label="source_provenance_v902"):
    """Return schema errors for a v902 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 902:
        return [f"{label}.schema_version must be 902"]
    return []
