"""Schema-906 source provenance validator."""


def validate_v906(value, label="source_provenance_v906"):
    """Return schema errors for a v906 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 906:
        return [f"{label}.schema_version must be 906"]
    return []
