import unittest
from tools.package.source_hash_provenance_v309 import validate_v309
def record()->dict:
    b={"source_id":"source-309","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"30.9.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"attestation_link_id":"attestation-link-309","attestation_link_digest":"d"*64,"attestation_link_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":309,"build_label":"source-provenance-v309",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"attestation_link":{"status":"PASS","evidence":"link","attestation_link_id":"attestation-link-309","attestation_link_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"attestation_link_entry_count":4,"bound":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV309Test(unittest.TestCase):
    def test_accepts_link_binding_and_not_run_gates(self):self.assertEqual(validate_v309(record()),[])
    def test_requires_matching_link_digest_and_count(self):
        i=record();i["attestation_link"]["attestation_link_digest"]="e"*64;i["attestation_link"]["attestation_link_entry_count"]=5;e=validate_v309(i);self.assertTrue(any("attestation_link.attestation_link_digest must match" in x for x in e));self.assertTrue(any("attestation_link.attestation_link_entry_count must match" in x for x in e))
    def test_rejects_schema_or_bound_flag(self):
        i=record();i["schema_version"]=308;i["attestation_link"]["bound"]=False;e=validate_v309(i);self.assertTrue(any("schema_version must be 309" in x for x in e));self.assertTrue(any("attestation_link.bound must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v309(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
