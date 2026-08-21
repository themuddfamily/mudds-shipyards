import unittest
from tools.package.source_hash_provenance_v314 import validate_v314
def record()->dict:
    b={"source_id":"source-314","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"31.4.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"approval_id":"approval-314","approval_digest":"d"*64,"approval_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":314,"build_label":"source-provenance-v314",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"approval":{"status":"PASS","evidence":"approval","approval_id":"approval-314","approval_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"approval_entry_count":4,"approved":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV314Test(unittest.TestCase):
    def test_accepts_approval_binding_and_not_run_gates(self):self.assertEqual(validate_v314(record()),[])
    def test_requires_matching_approval_digest_and_count(self):
        i=record();i["approval"]["approval_digest"]="e"*64;i["approval"]["approval_entry_count"]=5;e=validate_v314(i);self.assertTrue(any("approval.approval_digest must match" in x for x in e));self.assertTrue(any("approval.approval_entry_count must match" in x for x in e))
    def test_rejects_schema_or_approved_flag(self):
        i=record();i["schema_version"]=313;i["approval"]["approved"]=False;e=validate_v314(i);self.assertTrue(any("schema_version must be 314" in x for x in e));self.assertTrue(any("approval.approved must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v314(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
