import unittest
from tools.package.source_hash_provenance_v318 import validate_v318
def record()->dict:
    b={"source_id":"source-318","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"31.8.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"authorization_leaf_id":"authorization-leaf-318","authorization_leaf_digest":"d"*64,"authorization_leaf_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":318,"build_label":"source-provenance-v318",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"authorization_leaf":{"status":"PASS","evidence":"leaf","authorization_leaf_id":"authorization-leaf-318","authorization_leaf_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"authorization_leaf_entry_count":4,"authorized":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV318Test(unittest.TestCase):
    def test_accepts_leaf_binding_and_not_run_gates(self):self.assertEqual(validate_v318(record()),[])
    def test_requires_matching_leaf_digest_and_count(self):
        i=record();i["authorization_leaf"]["authorization_leaf_digest"]="e"*64;i["authorization_leaf"]["authorization_leaf_entry_count"]=5;e=validate_v318(i);self.assertTrue(any("authorization_leaf.authorization_leaf_digest must match" in x for x in e));self.assertTrue(any("authorization_leaf.authorization_leaf_entry_count must match" in x for x in e))
    def test_rejects_schema_or_authorized_flag(self):
        i=record();i["schema_version"]=317;i["authorization_leaf"]["authorized"]=False;e=validate_v318(i);self.assertTrue(any("schema_version must be 318" in x for x in e));self.assertTrue(any("authorization_leaf.authorized must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v318(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
