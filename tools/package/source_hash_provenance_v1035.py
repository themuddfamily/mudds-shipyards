"""Schema-1035 source provenance validator."""


def validate_v1035(value, label="source_provenance_v1035"):
    """Return schema errors for a v1035 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1035:
        return [f"{label}.schema_version must be 1035"]
    return []
