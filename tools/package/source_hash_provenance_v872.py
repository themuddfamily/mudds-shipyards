"""Schema-872 source provenance validator."""


def validate_v872(value, label="source_provenance_v872"):
    """Return schema errors for a v872 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 872:
        return [f"{label}.schema_version must be 872"]
    return []
