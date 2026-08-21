import unittest
from tools.package.source_hash_provenance_v300 import validate_v300
def record()->dict:
    b={"source_id":"source-300","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"30.0.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"graph_id":"graph-300","graph_digest":"d"*64,"graph_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":300,"build_label":"source-provenance-v300",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"graph":{"status":"PASS","evidence":"graph","graph_id":"graph-300","graph_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"graph_entry_count":4,"complete":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV300Test(unittest.TestCase):
    def test_accepts_graph_binding_and_not_run_gates(self):self.assertEqual(validate_v300(record()),[])
    def test_requires_matching_graph_digest_and_count(self):
        i=record();i["graph"]["graph_digest"]="e"*64;i["graph"]["graph_entry_count"]=5;e=validate_v300(i);self.assertTrue(any("graph.graph_digest must match" in x for x in e));self.assertTrue(any("graph.graph_entry_count must match" in x for x in e))
    def test_rejects_schema_or_complete_flag(self):
        i=record();i["schema_version"]=299;i["graph"]["complete"]=False;e=validate_v300(i);self.assertTrue(any("schema_version must be 300" in x for x in e));self.assertTrue(any("graph.complete must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v300(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
