"""Schema-875 source provenance validator."""


def validate_v875(value, label="source_provenance_v875"):
    """Return schema errors for a v875 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 875:
        return [f"{label}.schema_version must be 875"]
    return []
