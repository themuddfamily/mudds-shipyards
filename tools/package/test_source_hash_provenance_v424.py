import unittest
from tools.package.source_hash_provenance_v424 import validate_v424
def record():
 b={"source_id":"source-424","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"42.4.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"authorization_attestation_id":"authorization-attestation-424","authorization_attestation_digest":"d"*64,"authorization_attestation_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
 return {"schema_version":424,"build_label":"source-provenance-v424",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"authorization_attestation":{"status":"PASS","evidence":"attestation","authorization_attestation_id":b["authorization_attestation_id"],"authorization_attestation_digest":b["authorization_attestation_digest"],"source_hash":b["source_hash"],"package_artifact_hash_count":3,"authorization_attestation_entry_count":4,"authorized":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class V424Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v424(record()),[])
 def test_binding(self):
  x=record();x["authorization_attestation"]["authorization_attestation_digest"]="e"*64;self.assertTrue(any("must match" in z for z in validate_v424(x)))
 def test_schema_authorized(self):
  x=record();x["schema_version"]=423;x["authorization_attestation"]["authorized"]=False;e=validate_v424(x);self.assertTrue(any("schema_version" in z for z in e));self.assertTrue(any("authorized" in z for z in e))
 def test_not_run(self):
  x=record();x["native_execution"]["platform"]="Windows";self.assertTrue(any("platform" in z for z in validate_v424(x)))
if __name__=="__main__":unittest.main()
