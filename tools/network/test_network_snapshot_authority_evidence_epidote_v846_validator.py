import copy,hashlib,unittest
try:
 from .network_snapshot_authority_evidence_epidote_v846_validator import validate_snapshot
except ImportError:
 from network_snapshot_authority_evidence_epidote_v846_validator import validate_snapshot
def _item(o,i,d,s):
 x={"order":o,"item_id":i,"assertion_id":"authority-snapshot-evidence-epidote-assertion-v1","integrity_gate_id":"authority-evidence-epidote-v846","snapshot_id":"snapshot-authority-v729","authority":"server","sequence":50746,"subject":s,"authority_digest":d,"snapshot_digest":d,"asserted":True,"mutation_fields":[],"state_changed":False};f=("assertion_id","integrity_gate_id","snapshot_id","sequence","subject","authority_digest","snapshot_digest");x["assertion_digest"]=hashlib.sha256("|".join(str(x[k])for k in f).encode()).hexdigest();return x
def _nr(r):return{"status":"NOT_RUN","evidence":None,"reason":r}
def _report():
 a=[_item(1,"authority",hashlib.sha256(b"authority").hexdigest(),"authority"),_item(2,"epidote",hashlib.sha256(b"epidote").hexdigest(),"epidote")];m="\n".join(f"{x['order']}|{x['item_id']}|{x['assertion_digest']}"for x in a)
 return{"schema_version":846,"evidence_scope":"network_snapshot_authority_evidence_epidote_v846","evidence_mode":"detached_contract_fixture","policy_version":"network_replication_interest_authority_v1","authority":"server","integrity_gate_id":"authority-evidence-epidote-v846","snapshot_id":"snapshot-authority-v729","assertion_id":"authority-snapshot-evidence-epidote-assertion-v1","source":"server_snapshot","snapshot_version":618,"release":"release-1","native_claims":False,"uses_live_network":False,"snapshot_detached":True,"no_mutation_guarantee":True,"stale_check":_nr("Detached fixture does not execute stale replay checks."),"native_run":_nr("Native transport is outside this validator scope."),"hardware_run":_nr("Hardware validation is outside this validator scope."),"human_review":_nr("Human review is outside this validator scope."),"snapshot":{"integrity_gate_id":"authority-evidence-epidote-v846","snapshot_id":"snapshot-authority-v729","assertion_id":"authority-snapshot-evidence-epidote-assertion-v1","authority":"server","source":"server_snapshot","release":"release-1","version":618,"sequence":50746,"digest":hashlib.sha256(b"snapshot").hexdigest()},"assertion_members":a,"rollup_digest":hashlib.sha256(m.encode()).hexdigest(),"counts":{"assertion_members":2,"unique":2,"asserted":2,"mutations":0}}
class NetworkSnapshotAuthorityEvidenceEpidoteV846ValidatorTest(unittest.TestCase):
 def test_accepts_evidence_epidote_rollup(self):self.assertEqual(validate_snapshot(_report()),[])
 def test_rejects_evidence_epidote_binding(self):r=_report();r["assertion_members"][0]["snapshot_id"]="wrong-epidote";self.assertTrue(any("bind authority evidence epidote"in e for e in validate_snapshot(r)))
 def test_rejects_order_and_duplicate_identity(self):r=_report();r["assertion_members"][1].update(order=1,item_id="authority");e=validate_snapshot(r);self.assertTrue(any("order must be 2"in x for x in e));self.assertTrue(any("item_id must be unique"in x for x in e))
 def test_rejects_digest_and_counts(self):r=_report();r["assertion_members"][0]["snapshot_digest"]=hashlib.sha256(b"wrong").hexdigest();r["counts"]["asserted"]=9;e=validate_snapshot(r);self.assertTrue(any("snapshot_digest must match authority digest"in x for x in e));self.assertTrue(any("counts.asserted"in x for x in e))
 def test_rejects_rollup_and_mutation(self):r=_report();r["rollup_digest"]=hashlib.sha256(b"wrong").hexdigest();r["assertion_members"][0]["mutation_fields"]=["epidote"];r["counts"]["mutations"]=1;e=validate_snapshot(r);self.assertTrue(any("match authority evidence members"in x for x in e));self.assertTrue(any("must have no mutation"in x for x in e));self.assertTrue(any("counts.mutations must be zero"in x for x in e))
 def test_preserves_all_not_run_boundaries(self):
  r=_report()
  for k in("stale_check","native_run","hardware_run","human_review"):r[k].update(status="PASS",evidence="capture")
  e=validate_snapshot(r)
  for k in("stale_check","native_run","hardware_run","human_review"):self.assertTrue(any(f"{k}.status must remain NOT_RUN"in x for x in e))
 def test_rejects_live_or_native_claims(self):r=copy.deepcopy(_report());r.update(uses_live_network=True,native_claims=True);e=validate_snapshot(r);self.assertTrue(any("uses_live_network"in x for x in e));self.assertTrue(any("native_claims"in x for x in e))
if __name__=="__main__":unittest.main()
