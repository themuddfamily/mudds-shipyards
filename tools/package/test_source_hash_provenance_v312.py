import unittest
from tools.package.source_hash_provenance_v312 import validate_v312
def record()->dict:
    b={"source_id":"source-312","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"31.2.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"receipt_id":"receipt-312","receipt_digest":"d"*64,"receipt_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":312,"build_label":"source-provenance-v312",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"receipt":{"status":"PASS","evidence":"receipt","receipt_id":"receipt-312","receipt_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"receipt_entry_count":4,"accepted":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV312Test(unittest.TestCase):
    def test_accepts_receipt_binding_and_not_run_gates(self):self.assertEqual(validate_v312(record()),[])
    def test_requires_matching_receipt_digest_and_count(self):
        i=record();i["receipt"]["receipt_digest"]="e"*64;i["receipt"]["receipt_entry_count"]=5;e=validate_v312(i);self.assertTrue(any("receipt.receipt_digest must match" in x for x in e));self.assertTrue(any("receipt.receipt_entry_count must match" in x for x in e))
    def test_rejects_schema_or_accepted_flag(self):
        i=record();i["schema_version"]=311;i["receipt"]["accepted"]=False;e=validate_v312(i);self.assertTrue(any("schema_version must be 312" in x for x in e));self.assertTrue(any("receipt.accepted must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v312(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
