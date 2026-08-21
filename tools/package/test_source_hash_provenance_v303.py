import unittest
from tools.package.source_hash_provenance_v303 import validate_v303
def record()->dict:
    b={"source_id":"source-303","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"30.3.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"proof_id":"proof-303","proof_digest":"d"*64,"proof_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":303,"build_label":"source-provenance-v303",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"proof":{"status":"PASS","evidence":"proof","proof_id":"proof-303","proof_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"proof_entry_count":4,"valid":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV303Test(unittest.TestCase):
    def test_accepts_proof_binding_and_not_run_gates(self):self.assertEqual(validate_v303(record()),[])
    def test_requires_matching_proof_digest_and_count(self):
        i=record();i["proof"]["proof_digest"]="e"*64;i["proof"]["proof_entry_count"]=5;e=validate_v303(i);self.assertTrue(any("proof.proof_digest must match" in x for x in e));self.assertTrue(any("proof.proof_entry_count must match" in x for x in e))
    def test_rejects_schema_or_valid_flag(self):
        i=record();i["schema_version"]=302;i["proof"]["valid"]=False;e=validate_v303(i);self.assertTrue(any("schema_version must be 303" in x for x in e));self.assertTrue(any("proof.valid must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v303(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
