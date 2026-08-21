import unittest
from tools.package.source_hash_provenance_v311 import validate_v311
def record()->dict:
    b={"source_id":"source-311","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"31.1.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"checkpoint_id":"checkpoint-311","checkpoint_digest":"d"*64,"checkpoint_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":311,"build_label":"source-provenance-v311",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"checkpoint":{"status":"PASS","evidence":"checkpoint","checkpoint_id":"checkpoint-311","checkpoint_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"checkpoint_entry_count":4,"complete":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV311Test(unittest.TestCase):
    def test_accepts_checkpoint_binding_and_not_run_gates(self):self.assertEqual(validate_v311(record()),[])
    def test_requires_matching_checkpoint_digest_and_count(self):
        i=record();i["checkpoint"]["checkpoint_digest"]="e"*64;i["checkpoint"]["checkpoint_entry_count"]=5;e=validate_v311(i);self.assertTrue(any("checkpoint.checkpoint_digest must match" in x for x in e));self.assertTrue(any("checkpoint.checkpoint_entry_count must match" in x for x in e))
    def test_rejects_schema_or_complete_flag(self):
        i=record();i["schema_version"]=310;i["checkpoint"]["complete"]=False;e=validate_v311(i);self.assertTrue(any("schema_version must be 311" in x for x in e));self.assertTrue(any("checkpoint.complete must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v311(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
