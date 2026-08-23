"""Schema-890 source provenance validator."""


def validate_v890(value, label="source_provenance_v890"):
    """Return schema errors for a v890 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 890:
        return [f"{label}.schema_version must be 890"]
    return []
