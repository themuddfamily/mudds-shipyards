import unittest
from tools.package.source_hash_provenance_v298 import validate_v298
def record()->dict:
    b={"source_id":"source-298","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"29.8.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"node_id":"node-298","node_digest":"d"*64,"node_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":298,"build_label":"source-provenance-v298",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"node":{"status":"PASS","evidence":"node","node_id":"node-298","node_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"node_entry_count":4,"bound":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV298Test(unittest.TestCase):
    def test_accepts_node_binding_and_not_run_gates(self):self.assertEqual(validate_v298(record()),[])
    def test_requires_matching_node_digest_and_count(self):
        i=record();i["node"]["node_digest"]="e"*64;i["node"]["node_entry_count"]=5;e=validate_v298(i);self.assertTrue(any("node.node_digest must match" in x for x in e));self.assertTrue(any("node.node_entry_count must match" in x for x in e))
    def test_rejects_schema_or_bound_flag(self):
        i=record();i["schema_version"]=297;i["node"]["bound"]=False;e=validate_v298(i);self.assertTrue(any("schema_version must be 298" in x for x in e));self.assertTrue(any("node.bound must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v298(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
