import unittest
from tools.package.source_hash_provenance_v291 import validate_v291
def record()->dict:
    b={"source_id":"source-291","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"29.1.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"scope_id":"scope-291","scope_digest":"d"*64,"scope_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":291,"build_label":"source-provenance-v291",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"scope":{"status":"PASS","evidence":"scope","scope_id":"scope-291","scope_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"scope_entry_count":4,"closed":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV291Test(unittest.TestCase):
    def test_accepts_scope_binding_and_not_run_gates(self):self.assertEqual(validate_v291(record()),[])
    def test_requires_matching_scope_digest_and_count(self):
        i=record();i["scope"]["scope_digest"]="e"*64;i["scope"]["scope_entry_count"]=5;e=validate_v291(i);self.assertTrue(any("scope.scope_digest must match" in x for x in e));self.assertTrue(any("scope.scope_entry_count must match" in x for x in e))
    def test_rejects_schema_or_closed_flag(self):
        i=record();i["schema_version"]=290;i["scope"]["closed"]=False;e=validate_v291(i);self.assertTrue(any("schema_version must be 291" in x for x in e));self.assertTrue(any("scope.closed must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v291(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
