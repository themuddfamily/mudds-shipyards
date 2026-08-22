import copy,hashlib,unittest
try:
    from .network_snapshot_authority_evidence_capsule_v454_validator import validate_snapshot
except ImportError:
    from network_snapshot_authority_evidence_capsule_v454_validator import validate_snapshot

def _item(order,item_id,digest,subject):
    item={"order":order,"item_id":item_id,"assertion_id":"authority-snapshot-evidence-capsule-assertion-v1","integrity_gate_id":"authority-evidence-capsule-v454","snapshot_id":"snapshot-authority-v337","authority":"server","sequence":50354,"subject":subject,"authority_digest":digest,"snapshot_digest":digest,"asserted":True,"mutation_fields":[],"state_changed":False}
    fields=("assertion_id","integrity_gate_id","snapshot_id","sequence","subject","authority_digest","snapshot_digest")
    item["assertion_digest"]=hashlib.sha256("|".join(str(item[key]) for key in fields).encode()).hexdigest();return item
def _not_run(reason):return{"status":"NOT_RUN","evidence":None,"reason":reason}
def _report():
    members=[_item(1,"authority",hashlib.sha256(b"authority").hexdigest(),"authority"),_item(2,"capsule",hashlib.sha256(b"capsule").hexdigest(),"capsule")]
    rollup="\n".join(f"{item['order']}|{item['item_id']}|{item['assertion_digest']}" for item in members)
    return{"schema_version":454,"evidence_scope":"network_snapshot_authority_evidence_capsule_v454","evidence_mode":"detached_contract_fixture","policy_version":"network_replication_interest_authority_v1","authority":"server","integrity_gate_id":"authority-evidence-capsule-v454","snapshot_id":"snapshot-authority-v337","assertion_id":"authority-snapshot-evidence-capsule-assertion-v1","source":"server_snapshot","snapshot_version":226,"release":"release-1","native_claims":False,"uses_live_network":False,"snapshot_detached":True,"no_mutation_guarantee":True,"stale_check":_not_run("Detached fixture does not execute stale replay checks."),"native_run":_not_run("Native transport is outside this validator scope."),"hardware_run":_not_run("Hardware validation is outside this validator scope."),"human_review":_not_run("Human review is outside this validator scope."),"snapshot":{"integrity_gate_id":"authority-evidence-capsule-v454","snapshot_id":"snapshot-authority-v337","assertion_id":"authority-snapshot-evidence-capsule-assertion-v1","authority":"server","source":"server_snapshot","release":"release-1","version":226,"sequence":50354,"digest":hashlib.sha256(b"snapshot").hexdigest()},"assertion_members":members,"rollup_digest":hashlib.sha256(rollup.encode()).hexdigest(),"counts":{"assertion_members":2,"unique":2,"asserted":2,"mutations":0}}

class NetworkSnapshotAuthorityEvidenceCapsuleV454ValidatorTest(unittest.TestCase):
    def test_accepts_evidence_capsule_rollup(self):self.assertEqual(validate_snapshot(_report()),[])
    def test_rejects_evidence_capsule_binding(self):
        report=_report();report["assertion_members"][0]["snapshot_id"]="wrong-capsule";self.assertTrue(any("bind authority evidence capsule" in error for error in validate_snapshot(report)))
    def test_rejects_order_and_duplicate_identity(self):
        report=_report();report["assertion_members"][1].update(order=1,item_id="authority");errors=validate_snapshot(report);self.assertTrue(any("order must be 2" in error for error in errors));self.assertTrue(any("item_id must be unique" in error for error in errors))
    def test_rejects_digest_and_counts(self):
        report=_report();report["assertion_members"][0]["snapshot_digest"]=hashlib.sha256(b"wrong").hexdigest();report["counts"]["asserted"]=9;errors=validate_snapshot(report);self.assertTrue(any("snapshot_digest must match authority digest" in error for error in errors));self.assertTrue(any("counts.asserted" in error for error in errors))
    def test_rejects_rollup_and_mutation(self):
        report=_report();report["rollup_digest"]=hashlib.sha256(b"wrong").hexdigest();report["assertion_members"][0]["mutation_fields"]=["capsule"];report["counts"]["mutations"]=1;errors=validate_snapshot(report);self.assertTrue(any("match authority evidence members" in error for error in errors));self.assertTrue(any("must have no mutation" in error for error in errors));self.assertTrue(any("counts.mutations must be zero" in error for error in errors))
    def test_preserves_all_not_run_boundaries(self):
        report=_report()
        for key in ("stale_check","native_run","hardware_run","human_review"):report[key].update(status="PASS",evidence="capture")
        errors=validate_snapshot(report)
        for key in ("stale_check","native_run","hardware_run","human_review"):self.assertTrue(any(f"{key}.status must remain NOT_RUN" in error for error in errors))
    def test_rejects_live_or_native_claims(self):
        report=copy.deepcopy(_report());report.update(uses_live_network=True,native_claims=True);errors=validate_snapshot(report);self.assertTrue(any("uses_live_network" in error for error in errors));self.assertTrue(any("native_claims" in error for error in errors))
if __name__=="__main__":unittest.main()
