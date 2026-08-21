import unittest
from tools.package.source_hash_provenance_v288 import validate_v288
def record()->dict:
    b={"source_id":"source-288","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"28.8.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"release_id":"release-288","release_digest":"d"*64,"release_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":288,"build_label":"source-provenance-v288",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"release":{"status":"PASS","evidence":"release","release_id":"release-288","release_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"release_entry_count":4,"aligned":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV288Test(unittest.TestCase):
    def test_accepts_release_binding_and_not_run_gates(self):self.assertEqual(validate_v288(record()),[])
    def test_requires_matching_release_digest_and_count(self):
        i=record();i["release"]["release_digest"]="e"*64;i["release"]["release_entry_count"]=5;e=validate_v288(i);self.assertTrue(any("release.release_digest must match" in x for x in e));self.assertTrue(any("release.release_entry_count must match" in x for x in e))
    def test_rejects_schema_or_alignment_flag(self):
        i=record();i["schema_version"]=287;i["release"]["aligned"]=False;e=validate_v288(i);self.assertTrue(any("schema_version must be 288" in x for x in e));self.assertTrue(any("release.aligned must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v288(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
