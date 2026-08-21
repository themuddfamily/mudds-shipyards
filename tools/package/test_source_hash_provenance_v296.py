import unittest
from tools.package.source_hash_provenance_v296 import validate_v296
def record()->dict:
    b={"source_id":"source-296","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"29.6.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"root_id":"root-296","root_digest":"d"*64,"root_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":296,"build_label":"source-provenance-v296",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"root":{"status":"PASS","evidence":"root","root_id":"root-296","root_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"root_entry_count":4,"closed":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV296Test(unittest.TestCase):
    def test_accepts_root_binding_and_not_run_gates(self):self.assertEqual(validate_v296(record()),[])
    def test_requires_matching_root_digest_and_count(self):
        i=record();i["root"]["root_digest"]="e"*64;i["root"]["root_entry_count"]=5;e=validate_v296(i);self.assertTrue(any("root.root_digest must match" in x for x in e));self.assertTrue(any("root.root_entry_count must match" in x for x in e))
    def test_rejects_schema_or_closed_flag(self):
        i=record();i["schema_version"]=295;i["root"]["closed"]=False;e=validate_v296(i);self.assertTrue(any("schema_version must be 296" in x for x in e));self.assertTrue(any("root.closed must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v296(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
