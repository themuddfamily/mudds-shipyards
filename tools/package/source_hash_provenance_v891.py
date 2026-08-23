"""Schema-891 source provenance validator."""


def validate_v891(value, label="source_provenance_v891"):
    """Return schema errors for a v891 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 891:
        return [f"{label}.schema_version must be 891"]
    return []
