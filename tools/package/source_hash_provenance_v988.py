"""Schema-988 source provenance validator."""


def validate_v988(value, label="source_provenance_v988"):
    """Return schema errors for a v988 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 988:
        return [f"{label}.schema_version must be 988"]
    return []
