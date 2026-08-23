"""Schema-940 source provenance validator."""


def validate_v940(value, label="source_provenance_v940"):
    """Return schema errors for a v940 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 940:
        return [f"{label}.schema_version must be 940"]
    return []
