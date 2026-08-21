import unittest
from tools.package.source_hash_provenance_v280 import validate_v280
def record():
    c={"source_id":"source-280","source_commit":"b"*40,"source_hash":"c"*64,"source_version":"src-280","package_version":"28.0.0","source_artifact_digest_count":1,"package_artifact_digest_count":2};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":280,"build_label":"source-provenance-v280",**c,"provenance_id":"provenance-280","source":{"status":"PASS","evidence":"source-record",**c,"identified":True},"provenance":{"status":"PASS","evidence":"provenance-record","provenance_id":"provenance-280",**c,"proven":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV280Test(unittest.TestCase):
    def test_accepts_artifact_digest_counts_and_not_run_gates(self):self.assertEqual(validate_v280(record()),[])
    def test_requires_matching_artifact_digest_counts(self):
        i=record();i["source"]["source_artifact_digest_count"]=0;i["provenance"]["package_artifact_digest_count"]=3;e=validate_v280(i);self.assertTrue(any("source.source_artifact_digest_count must match" in x for x in e));self.assertTrue(any("provenance.package_artifact_digest_count must match" in x for x in e))
    def test_rejects_schema_or_provenance_flag(self):
        i=record();i["schema_version"]=279;i["provenance"]["proven"]=False;e=validate_v280(i);self.assertTrue(any("schema_version must be 280" in x for x in e));self.assertTrue(any("proven must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_hardware_or_reviewer(self):
        i=record();i["hardware_execution"]["hardware"]="GPU";i["human_review"]["reviewer"]="alice";e=validate_v280(i);self.assertTrue(any("hardware_execution.hardware must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
