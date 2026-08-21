import copy,unittest
from tools.settings.review.accessibility_runtime_outcome_record_provenance_v335_validator import validate_runtime_outcome_record_provenance,SCHEMA
from tools.settings.review.accessibility_runtime_outcome_record_provenance_v306_validator import SOURCE_SCHEMA,OUTCOME_POLICY,BINDING,AUTHORITY,SOURCE_ID,CONTRACT_ID
def rec():return {"schema":SCHEMA,"source_schema":SOURCE_SCHEMA,"schema_version":"v335","source_revision":"r","reviewer_required":"human","open_gate_reason":"open","human_review_status":"not_performed","native_render_status":"not_run","human_review_performed":False,"native_render_performed":False,"policy_verified":False,"runtime_claimed":False,"outcome_written":False,"outcome_confirmed":False,"outcome_policy":copy.deepcopy(OUTCOME_POLICY),"binding":copy.deepcopy(BINDING),"authority":copy.deepcopy(AUTHORITY),"source_id":SOURCE_ID,"contract_id":CONTRACT_ID,"provenance_source_of_truth":"runtime_accessibility_outcome_record_policy","status":"planned","evidence":None,**AUTHORITY}
class AccessibilityRuntimeOutcomeRecordProvenanceV335Tests(unittest.TestCase):
 def test_complete(self):self.assertEqual(validate_runtime_outcome_record_provenance(rec()),[])
 def test_schema(self):v=rec();v["schema"]="bad";self.assertTrue(validate_runtime_outcome_record_provenance(v))
 def test_policy(self):v=rec();v["outcome_policy"]=[];self.assertTrue(validate_runtime_outcome_record_provenance(v))
 def test_fields(self):v=rec();v["outcome_policy"]["outcome_fields"]=[];self.assertTrue(validate_runtime_outcome_record_provenance(v))
 def test_gates(self):v=rec();v["native_render_status"]="passed";self.assertTrue(validate_runtime_outcome_record_provenance(v))
 def test_authority(self):v=rec();v["authority"]=[];self.assertTrue(validate_runtime_outcome_record_provenance(v))
