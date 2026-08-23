"""Schema-939 source provenance validator."""


def validate_v939(value, label="source_provenance_v939"):
    """Return schema errors for a v939 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 939:
        return [f"{label}.schema_version must be 939"]
    return []
