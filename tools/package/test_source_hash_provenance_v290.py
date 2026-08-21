import unittest
from tools.package.source_hash_provenance_v290 import validate_v290
def record()->dict:
    b={"source_id":"source-290","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"29.0.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"target_id":"target-290","target_digest":"d"*64,"target_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":290,"build_label":"source-provenance-v290",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"target":{"status":"PASS","evidence":"target","target_id":"target-290","target_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"target_entry_count":4,"bound":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV290Test(unittest.TestCase):
    def test_accepts_target_binding_and_not_run_gates(self):self.assertEqual(validate_v290(record()),[])
    def test_requires_matching_target_digest_and_count(self):
        i=record();i["target"]["target_digest"]="e"*64;i["target"]["target_entry_count"]=5;e=validate_v290(i);self.assertTrue(any("target.target_digest must match" in x for x in e));self.assertTrue(any("target.target_entry_count must match" in x for x in e))
    def test_rejects_schema_or_bound_flag(self):
        i=record();i["schema_version"]=289;i["target"]["bound"]=False;e=validate_v290(i);self.assertTrue(any("schema_version must be 290" in x for x in e));self.assertTrue(any("target.bound must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v290(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
