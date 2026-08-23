"""Schema-975 source provenance validator."""


def validate_v975(value, label="source_provenance_v975"):
    """Return schema errors for a v975 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 975:
        return [f"{label}.schema_version must be 975"]
    return []
