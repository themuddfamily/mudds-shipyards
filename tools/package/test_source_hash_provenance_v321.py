import unittest
from tools.package.source_hash_provenance_v321 import validate_v321
def record()->dict:
    b={"source_id":"source-321","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"32.1.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"authorization_record_id":"authorization-record-321","authorization_record_digest":"d"*64,"authorization_record_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":321,"build_label":"source-provenance-v321",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"authorization_record":{"status":"PASS","evidence":"record","authorization_record_id":"authorization-record-321","authorization_record_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"authorization_record_entry_count":4,"authorized":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV321Test(unittest.TestCase):
    def test_accepts_record_binding_and_not_run_gates(self):self.assertEqual(validate_v321(record()),[])
    def test_requires_matching_record_digest_and_count(self):
        i=record();i["authorization_record"]["authorization_record_digest"]="e"*64;i["authorization_record"]["authorization_record_entry_count"]=5;e=validate_v321(i);self.assertTrue(any("authorization_record.authorization_record_digest must match" in x for x in e));self.assertTrue(any("authorization_record.authorization_record_entry_count must match" in x for x in e))
    def test_rejects_schema_or_authorized_flag(self):
        i=record();i["schema_version"]=320;i["authorization_record"]["authorized"]=False;e=validate_v321(i);self.assertTrue(any("schema_version must be 321" in x for x in e));self.assertTrue(any("authorization_record.authorized must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v321(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
