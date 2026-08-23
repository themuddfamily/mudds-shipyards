"""Schema-912 source provenance validator."""


def validate_v912(value, label="source_provenance_v912"):
    """Return schema errors for a v912 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 912:
        return [f"{label}.schema_version must be 912"]
    return []
