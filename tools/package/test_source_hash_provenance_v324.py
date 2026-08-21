import unittest
from tools.package.source_hash_provenance_v324 import validate_v324
def record()->dict:
    b={"source_id":"source-324","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"32.4.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"authorization_proof_id":"authorization-proof-324","authorization_proof_digest":"d"*64,"authorization_proof_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":324,"build_label":"source-provenance-v324",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"authorization_proof":{"status":"PASS","evidence":"proof","authorization_proof_id":"authorization-proof-324","authorization_proof_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"authorization_proof_entry_count":4,"valid":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV324Test(unittest.TestCase):
    def test_accepts_proof_binding_and_not_run_gates(self):self.assertEqual(validate_v324(record()),[])
    def test_requires_matching_proof_digest_and_count(self):
        i=record();i["authorization_proof"]["authorization_proof_digest"]="e"*64;i["authorization_proof"]["authorization_proof_entry_count"]=5;e=validate_v324(i);self.assertTrue(any("authorization_proof.authorization_proof_digest must match" in x for x in e));self.assertTrue(any("authorization_proof.authorization_proof_entry_count must match" in x for x in e))
    def test_rejects_schema_or_valid_flag(self):
        i=record();i["schema_version"]=323;i["authorization_proof"]["valid"]=False;e=validate_v324(i);self.assertTrue(any("schema_version must be 324" in x for x in e));self.assertTrue(any("authorization_proof.valid must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v324(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
