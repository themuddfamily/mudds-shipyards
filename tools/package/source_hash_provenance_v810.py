"""Schema-810 source provenance validator."""


def validate_v810(value, label="source_provenance_v810"):
    """Return schema errors for a v810 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 810:
        return [f"{label}.schema_version must be 810"]
    return []
