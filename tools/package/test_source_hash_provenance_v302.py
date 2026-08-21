import unittest
from tools.package.source_hash_provenance_v302 import validate_v302
def record()->dict:
    b={"source_id":"source-302","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"30.2.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"reconciliation_id":"reconcile-302","reconciliation_digest":"d"*64,"reconciliation_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":302,"build_label":"source-provenance-v302",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"reconciliation":{"status":"PASS","evidence":"reconciliation","reconciliation_id":"reconcile-302","reconciliation_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"reconciliation_entry_count":4,"reconciled":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV302Test(unittest.TestCase):
    def test_accepts_reconciliation_binding_and_not_run_gates(self):self.assertEqual(validate_v302(record()),[])
    def test_requires_matching_reconciliation_digest_and_count(self):
        i=record();i["reconciliation"]["reconciliation_digest"]="e"*64;i["reconciliation"]["reconciliation_entry_count"]=5;e=validate_v302(i);self.assertTrue(any("reconciliation.reconciliation_digest must match" in x for x in e));self.assertTrue(any("reconciliation.reconciliation_entry_count must match" in x for x in e))
    def test_rejects_schema_or_reconciled_flag(self):
        i=record();i["schema_version"]=301;i["reconciliation"]["reconciled"]=False;e=validate_v302(i);self.assertTrue(any("schema_version must be 302" in x for x in e));self.assertTrue(any("reconciliation.reconciled must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v302(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
