import unittest
from tools.package.source_hash_provenance_v292 import validate_v292
def record()->dict:
    b={"source_id":"source-292","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"29.2.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"boundary_id":"boundary-292","boundary_digest":"d"*64,"boundary_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":292,"build_label":"source-provenance-v292",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"boundary":{"status":"PASS","evidence":"boundary","boundary_id":"boundary-292","boundary_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"boundary_entry_count":4,"sealed":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV292Test(unittest.TestCase):
    def test_accepts_boundary_binding_and_not_run_gates(self):self.assertEqual(validate_v292(record()),[])
    def test_requires_matching_boundary_digest_and_count(self):
        i=record();i["boundary"]["boundary_digest"]="e"*64;i["boundary"]["boundary_entry_count"]=5;e=validate_v292(i);self.assertTrue(any("boundary.boundary_digest must match" in x for x in e));self.assertTrue(any("boundary.boundary_entry_count must match" in x for x in e))
    def test_rejects_schema_or_sealed_flag(self):
        i=record();i["schema_version"]=291;i["boundary"]["sealed"]=False;e=validate_v292(i);self.assertTrue(any("schema_version must be 292" in x for x in e));self.assertTrue(any("boundary.sealed must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v292(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
