import unittest
from tools.package.source_hash_provenance_v295 import validate_v295
def record()->dict:
    b={"source_id":"source-295","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"29.5.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"manifest_chain_id":"manifest-chain-295","manifest_chain_digest":"d"*64,"manifest_chain_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":295,"build_label":"source-provenance-v295",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"manifest_chain":{"status":"PASS","evidence":"manifest-chain","manifest_chain_id":"manifest-chain-295","manifest_chain_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"manifest_chain_entry_count":4,"complete":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV295Test(unittest.TestCase):
    def test_accepts_manifest_chain_binding_and_not_run_gates(self):self.assertEqual(validate_v295(record()),[])
    def test_requires_matching_chain_digest_and_count(self):
        i=record();i["manifest_chain"]["manifest_chain_digest"]="e"*64;i["manifest_chain"]["manifest_chain_entry_count"]=5;e=validate_v295(i);self.assertTrue(any("manifest_chain.manifest_chain_digest must match" in x for x in e));self.assertTrue(any("manifest_chain.manifest_chain_entry_count must match" in x for x in e))
    def test_rejects_schema_or_complete_flag(self):
        i=record();i["schema_version"]=294;i["manifest_chain"]["complete"]=False;e=validate_v295(i);self.assertTrue(any("schema_version must be 295" in x for x in e));self.assertTrue(any("manifest_chain.complete must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v295(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
