"""Schema-840 source provenance validator."""


def validate_v840(value, label="source_provenance_v840"):
    """Return schema errors for a v840 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 840:
        return [f"{label}.schema_version must be 840"]
    return []
