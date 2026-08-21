import unittest
from tools.package.source_hash_provenance_v304 import validate_v304
def record()->dict:
    b={"source_id":"source-304","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"30.4.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"attestation_chain_id":"attestation-chain-304","attestation_chain_digest":"d"*64,"attestation_chain_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":304,"build_label":"source-provenance-v304",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"attestation_chain":{"status":"PASS","evidence":"attestation-chain","attestation_chain_id":"attestation-chain-304","attestation_chain_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"attestation_chain_entry_count":4,"complete":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV304Test(unittest.TestCase):
    def test_accepts_attestation_chain_binding_and_not_run_gates(self):self.assertEqual(validate_v304(record()),[])
    def test_requires_matching_chain_digest_and_count(self):
        i=record();i["attestation_chain"]["attestation_chain_digest"]="e"*64;i["attestation_chain"]["attestation_chain_entry_count"]=5;e=validate_v304(i);self.assertTrue(any("attestation_chain.attestation_chain_digest must match" in x for x in e));self.assertTrue(any("attestation_chain.attestation_chain_entry_count must match" in x for x in e))
    def test_rejects_schema_or_complete_flag(self):
        i=record();i["schema_version"]=303;i["attestation_chain"]["complete"]=False;e=validate_v304(i);self.assertTrue(any("schema_version must be 304" in x for x in e));self.assertTrue(any("attestation_chain.complete must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v304(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
