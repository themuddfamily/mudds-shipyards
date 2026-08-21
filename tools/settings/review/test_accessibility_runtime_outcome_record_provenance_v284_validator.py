import copy,unittest
from tools.settings.review.accessibility_runtime_outcome_record_provenance_v284_validator import AUTHORITY,BINDING,OUTCOME_POLICY,SCHEMA,SOURCE_ID,SOURCE_SCHEMA,validate_runtime_outcome_record_provenance
def _record()->dict:return {"schema":SCHEMA,"source_schema":SOURCE_SCHEMA,"schema_version":"v284","source_revision":"working-tree-runtime-outcome-record-v284","reviewer_required":"human accessibility and outcome-record QA","open_gate_reason":"human and native outcome validation have not been performed","human_review_status":"not_performed","native_render_status":"not_run","human_review_performed":False,"native_render_performed":False,"policy_verified":False,"runtime_claimed":False,"outcome_written":False,"outcome_confirmed":False,"outcome_policy":copy.deepcopy(OUTCOME_POLICY),"binding":copy.deepcopy(BINDING),"authority":copy.deepcopy(AUTHORITY),"source_id":SOURCE_ID,"contract_id":"runtime-accessibility-presentation","provenance_source_of_truth":"runtime_accessibility_outcome_record_policy","status":"planned","evidence":None,**AUTHORITY}
class AccessibilityRuntimeOutcomeRecordProvenanceV284Tests(unittest.TestCase):
 def test_complete_record_keeps_gates_open(self):self.assertEqual(validate_runtime_outcome_record_provenance(_record()),[])
 def test_outcome_policy_and_binding_are_exact(self):
  v=_record();v["outcome_policy"]["missing_artifact"]="claim_complete";v["binding"]["apply_rule"]="write_settings";e=validate_runtime_outcome_record_provenance(v);self.assertTrue(any("outcome_policy must exactly" in x for x in e));self.assertTrue(any("binding must exactly" in x for x in e))
 def test_outcome_fields_cannot_shrink(self):
  v=_record();v["outcome_policy"]["outcome_fields"]=["camera"];self.assertTrue(any("outcome_policy must exactly" in x for x in validate_runtime_outcome_record_provenance(v)))
 def test_native_and_outcome_claims_remain_open(self):
  v=_record();v["native_render_status"]="passed";v["outcome_written"]=True;e=validate_runtime_outcome_record_provenance(v);self.assertTrue(any("native_render_status must remain not_run" in x for x in e));self.assertTrue(any("outcome_written must be false" in x for x in e))
 def test_outcome_record_authority_fails_closed(self):
  v=_record();v["authority"]["outcome_record_authority"]=True;v["outcome_record_authority"]=True;e=validate_runtime_outcome_record_provenance(v);self.assertTrue(any("authority must exactly" in x for x in e));self.assertTrue(any("outcome_record_authority must be false" in x for x in e))
 def test_malformed_shapes_fail_without_throwing(self):
  v=_record();v["outcome_policy"]=[];v["binding"]=[];v["authority"]=[];v["evidence"]=[{"kind":[],"path":{},"sha256":[]}];e=validate_runtime_outcome_record_provenance(v);self.assertTrue(any("outcome_policy must exactly" in x for x in e));self.assertTrue(any("binding must exactly" in x for x in e));self.assertTrue(any("authority must exactly" in x for x in e));self.assertTrue(any("evidence[0].kind" in x for x in e))
