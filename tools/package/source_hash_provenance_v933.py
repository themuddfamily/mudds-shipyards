"""Schema-933 source provenance validator."""


def validate_v933(value, label="source_provenance_v933"):
    """Return schema errors for a v933 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 933:
        return [f"{label}.schema_version must be 933"]
    return []
