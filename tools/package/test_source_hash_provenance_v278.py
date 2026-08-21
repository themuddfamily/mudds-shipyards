import unittest
from tools.package.source_hash_provenance_v278 import validate_v278
def record():
    c={"source_id":"source-278","source_commit":"b"*40,"source_hash":"c"*64,"source_version":"src-278","package_version":"27.8.0","source_metadata_attestation_count":1,"package_metadata_attestation_count":2};g={"status":"NOT_RUN","evidence":None,"platform":None,"hardware":None,"reviewer":None,"evidence_path":None}
    return {"schema_version":278,"build_label":"source-provenance-v278",**c,"provenance_id":"provenance-278","source":{"status":"PASS","evidence":"source-record",**c,"identified":True},"provenance":{"status":"PASS","evidence":"provenance-record","provenance_id":"provenance-278",**c,"proven":True},"native_execution":dict(g),"hardware_execution":dict(g),"human_review":dict(g)}
class SourceHashProvenanceV278Test(unittest.TestCase):
    def test_accepts_metadata_attestation_counts_and_not_run_gates(self):self.assertEqual(validate_v278(record()),[])
    def test_requires_matching_metadata_attestation_counts(self):
        i=record();i["source"]["source_metadata_attestation_count"]=0;i["provenance"]["package_metadata_attestation_count"]=3;e=validate_v278(i);self.assertTrue(any("source.source_metadata_attestation_count must match" in x for x in e));self.assertTrue(any("provenance.package_metadata_attestation_count must match" in x for x in e))
    def test_rejects_schema_or_provenance_flag(self):
        i=record();i["schema_version"]=277;i["provenance"]["proven"]=False;e=validate_v278(i);self.assertTrue(any("schema_version must be 278" in x for x in e));self.assertTrue(any("proven must be true" in x for x in e))
    def test_not_run_gates_cannot_carry_hardware_or_reviewer(self):
        i=record();i["hardware_execution"]["hardware"]="GPU";i["human_review"]["reviewer"]="alice";e=validate_v278(i);self.assertTrue(any("hardware_execution.hardware must be null" in x for x in e));self.assertTrue(any("human_review.reviewer must be null" in x for x in e))
if __name__=="__main__":unittest.main()
