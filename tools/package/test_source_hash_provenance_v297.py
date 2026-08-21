import unittest
from tools.package.source_hash_provenance_v297 import validate_v297
def record()->dict:
    b={"source_id":"source-297","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"29.7.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"leaf_id":"leaf-297","leaf_digest":"d"*64,"leaf_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":297,"build_label":"source-provenance-v297",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"leaf":{"status":"PASS","evidence":"leaf","leaf_id":"leaf-297","leaf_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"leaf_entry_count":4,"verified":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV297Test(unittest.TestCase):
    def test_accepts_leaf_binding_and_not_run_gates(self):self.assertEqual(validate_v297(record()),[])
    def test_requires_matching_leaf_digest_and_count(self):
        i=record();i["leaf"]["leaf_digest"]="e"*64;i["leaf"]["leaf_entry_count"]=5;e=validate_v297(i);self.assertTrue(any("leaf.leaf_digest must match" in x for x in e));self.assertTrue(any("leaf.leaf_entry_count must match" in x for x in e))
    def test_rejects_schema_or_verified_flag(self):
        i=record();i["schema_version"]=296;i["leaf"]["verified"]=False;e=validate_v297(i);self.assertTrue(any("schema_version must be 297" in x for x in e));self.assertTrue(any("leaf.verified must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v297(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
