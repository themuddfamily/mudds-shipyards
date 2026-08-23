"""Schema-961 source provenance validator."""


def validate_v961(value, label="source_provenance_v961"):
    """Return schema errors for a v961 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 961:
        return [f"{label}.schema_version must be 961"]
    return []
