import unittest
from tools.package.source_hash_provenance_v307 import validate_v307
def record()->dict:
    b={"source_id":"source-307","source_commit":"b"*40,"source_hash":"c"*64,"package_version":"30.7.0","source_artifact_hash_count":2,"package_artifact_hash_count":3,"attestation_node_id":"attestation-node-307","attestation_node_digest":"d"*64,"attestation_node_entry_count":4};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":307,"build_label":"source-provenance-v307",**b,"source":{"status":"PASS","evidence":"source",**b,"identified":True},"attestation_node":{"status":"PASS","evidence":"node","attestation_node_id":"attestation-node-307","attestation_node_digest":"d"*64,"source_hash":"c"*64,"package_artifact_hash_count":3,"attestation_node_entry_count":4,"bound":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV307Test(unittest.TestCase):
    def test_accepts_node_binding_and_not_run_gates(self):self.assertEqual(validate_v307(record()),[])
    def test_requires_matching_node_digest_and_count(self):
        i=record();i["attestation_node"]["attestation_node_digest"]="e"*64;i["attestation_node"]["attestation_node_entry_count"]=5;e=validate_v307(i);self.assertTrue(any("attestation_node.attestation_node_digest must match" in x for x in e));self.assertTrue(any("attestation_node.attestation_node_entry_count must match" in x for x in e))
    def test_rejects_schema_or_bound_flag(self):
        i=record();i["schema_version"]=306;i["attestation_node"]["bound"]=False;e=validate_v307(i);self.assertTrue(any("schema_version must be 307" in x for x in e));self.assertTrue(any("attestation_node.bound must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_platform_or_reviewer(self):
        i=record();i["native_execution"]["platform"]="Windows";i["human_review"]["reviewer"]="alice";e=validate_v307(i);self.assertTrue(any("native_execution.platform must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
