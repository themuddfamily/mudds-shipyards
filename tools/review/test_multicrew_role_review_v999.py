import unittest

from tools.review.multicrew_role_review_v999 import validate_manifest


def manifest() -> dict:
    schema = "multicrew_role_review_v999"; vessel, review, root = "jovian_courier", "crew_review", "multicrew_root"; source = "working-tree-multicrew-review-v999"
    fixed = {"review_scope": "multicrew_role", "evidence_phase": "review", "review_mode": "evidence_only", "authority_class": "non_runtime_review", "closure_state": "open", "gate_policy": "native_human_open", "evidence_boundary": "pre_native_human", "evidence_revision": "v999"}
    policies = {f"runtime_{name}_policy": "forbidden" for name in ("write", "process", "network", "environment", "filesystem", "time", "random", "thread", "signal", "mutex", "ipc", "subprocess", "ui", "audio", "haptic", "display", "input", "storage", "cache", "gpu", "sensor")}
    shared = {**fixed, **policies}
    roles = [{"role_id": role + "_role", "role": role, "seat_id": vessel + "_" + role, "evidence_id": "evidence_" + role, "review_version": 999, **shared, "review_id": review, "vessel_id": vessel, "source_revision": source, "root_identity_value": root, "runtime_authority": False, "status": status} for role, status in (("pilot", "pending"), ("gunner", "not_performed"), ("passenger", "pending"), ("engineer", "not_performed"))]
    return {"schema": schema, "schema_version": 999, "review_version": 999, "world_id": "ember_moon", "vessel_id": vessel, "review_id": review, "source_revision": source, "root_id": root, "root_identity_value": root, **shared, "roles": roles, "native_render": {"status": "not_performed"}, "human_signoff": {"status": "pending"}, "claims_excluded": ["native_render", "human_signoff", "runtime_role_assignment", "live_multiplayer_claim"]}


class MulticrewRoleReviewV999Test(unittest.TestCase):
    def test_valid_open_manifest(self): self.assertEqual(validate_manifest(manifest()), [])
    def test_schema_version_strict(self):
        value = manifest(); value["schema_version"] = 187; self.assertTrue(any("schema_version must be 999" in e for e in validate_manifest(value)))
    def test_review_version_strict(self):
        value = manifest(); value["review_version"] = 187; self.assertTrue(any("review_version must be 999" in e for e in validate_manifest(value)))
    def test_role_identity_unique(self):
        value = manifest(); value["roles"][1]["role_id"] = value["roles"][0]["role_id"]; self.assertTrue(any("role_id" in e for e in validate_manifest(value)))
    def test_role_kind_supported(self):
        value = manifest(); value["roles"][0]["role"] = "captain"; self.assertTrue(any("supported crew role" in e for e in validate_manifest(value)))
    def test_role_policy_binding(self):
        value = manifest(); value["roles"][1]["runtime_network_policy"] = "allowed"; self.assertTrue(any("runtime_network_policy must match" in e for e in validate_manifest(value)))
    def test_source_revision_binding(self):
        value = manifest(); value["roles"][1]["source_revision"] = "other"; self.assertTrue(any("source_revision" in e for e in validate_manifest(value)))
    def test_role_status_open(self):
        value = manifest(); value["roles"][0]["status"] = "assigned"; self.assertTrue(any("status must remain open" in e for e in validate_manifest(value)))
    def test_review_gates_open(self):
        value = manifest(); value["native_render"]["status"] = "passed"; value["human_signoff"]["status"] = "approved"; errors = validate_manifest(value); self.assertTrue(any("native_render" in e for e in errors)); self.assertTrue(any("human_signoff" in e for e in errors))
    def test_exclusions_required(self):
        value = manifest(); value["claims_excluded"] = []; self.assertTrue(any("claims_excluded" in e for e in validate_manifest(value)))
    def test_non_object_role_fails_closed(self):
        value = manifest(); value["roles"][0] = None; self.assertTrue(any("roles[0] must be an object" in e for e in validate_manifest(value)))


if __name__ == "__main__": unittest.main()
