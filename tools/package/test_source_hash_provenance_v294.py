import unittest
from tools.package.source_hash_provenance_v294 import validate_v294
def record()->dict:
    b={"source_id":"source-294","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"29.4.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"chain_id":"chain-294","chain_digest":"d"*64,"chain_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":294,"build_label":"source-provenance-v294",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"chain":{"status":"PASS","evidence":"chain","chain_id":"chain-294","chain_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"chain_entry_count":4,"complete":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV294Test(unittest.TestCase):
    def test_accepts_chain_binding_and_not_run_gates(self):self.assertEqual(validate_v294(record()),[])
    def test_requires_matching_chain_digest_and_count(self):
        i=record();i["chain"]["chain_digest"]="e"*64;i["chain"]["chain_entry_count"]=5;e=validate_v294(i);self.assertTrue(any("chain.chain_digest must match" in x for x in e));self.assertTrue(any("chain.chain_entry_count must match" in x for x in e))
    def test_rejects_schema_or_complete_flag(self):
        i=record();i["schema_version"]=293;i["chain"]["complete"]=False;e=validate_v294(i);self.assertTrue(any("schema_version must be 294" in x for x in e));self.assertTrue(any("chain.complete must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v294(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
