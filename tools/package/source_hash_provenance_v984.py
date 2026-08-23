"""Schema-984 source provenance validator."""


def validate_v984(value, label="source_provenance_v984"):
    """Return schema errors for a v984 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 984:
        return [f"{label}.schema_version must be 984"]
    return []
