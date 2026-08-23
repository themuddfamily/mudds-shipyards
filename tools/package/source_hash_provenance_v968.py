"""Schema-968 source provenance validator."""


def validate_v968(value, label="source_provenance_v968"):
    """Return schema errors for a v968 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 968:
        return [f"{label}.schema_version must be 968"]
    return []
