"""Schema-995 source provenance validator."""


def validate_v995(value, label="source_provenance_v995"):
    """Return schema errors for a v995 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 995:
        return [f"{label}.schema_version must be 995"]
    return []
