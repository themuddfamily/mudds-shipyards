import unittest
from tools.package.source_hash_provenance_v289 import validate_v289
def record()->dict:
    b={"source_id":"source-289","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"28.9.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"channel_id":"channel-289","channel_digest":"d"*64,"channel_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":289,"build_label":"source-provenance-v289",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"channel":{"status":"PASS","evidence":"channel","channel_id":"channel-289","channel_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"channel_entry_count":4,"bound":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV289Test(unittest.TestCase):
    def test_accepts_channel_binding_and_not_run_gates(self):self.assertEqual(validate_v289(record()),[])
    def test_requires_matching_channel_digest_and_count(self):
        i=record();i["channel"]["channel_digest"]="e"*64;i["channel"]["channel_entry_count"]=5;e=validate_v289(i);self.assertTrue(any("channel.channel_digest must match" in x for x in e));self.assertTrue(any("channel.channel_entry_count must match" in x for x in e))
    def test_rejects_schema_or_bound_flag(self):
        i=record();i["schema_version"]=288;i["channel"]["bound"]=False;e=validate_v289(i);self.assertTrue(any("schema_version must be 289" in x for x in e));self.assertTrue(any("channel.bound must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v289(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
