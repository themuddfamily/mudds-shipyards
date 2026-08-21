import unittest
from tools.package.source_hash_provenance_v286 import validate_v286
def record()->dict:
    b={"source_id":"source-286","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"28.6.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"artifact_id":"artifact-286","artifact_hash":"d"*64,"artifact_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":286,"build_label":"source-provenance-v286",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"artifact":{"status":"PASS","evidence":"artifact","artifact_id":"artifact-286","artifact_hash":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"artifact_entry_count":4,"bound":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV286Test(unittest.TestCase):
    def test_accepts_artifact_binding_and_not_run_gates(self):self.assertEqual(validate_v286(record()),[])
    def test_requires_matching_artifact_hash_and_count(self):
        i=record();i["artifact"]["artifact_hash"]="e"*64;i["artifact"]["artifact_entry_count"]=5;e=validate_v286(i);self.assertTrue(any("artifact.artifact_hash must match" in x for x in e));self.assertTrue(any("artifact.artifact_entry_count must match" in x for x in e))
    def test_rejects_schema_or_bound_flag(self):
        i=record();i["schema_version"]=285;i["artifact"]["bound"]=False;e=validate_v286(i);self.assertTrue(any("schema_version must be 286" in x for x in e));self.assertTrue(any("artifact.bound must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v286(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
