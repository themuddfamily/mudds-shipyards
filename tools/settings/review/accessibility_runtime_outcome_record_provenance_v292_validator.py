#!/usr/bin/env python3
"""Validate v292 accessibility runtime outcome-record provenance evidence."""
from __future__ import annotations
import argparse,json,re
from pathlib import Path
from typing import Any
SCHEMA="accessibility_runtime_outcome_record_provenance_v292_evidence_v1"; SOURCE_SCHEMA="runtime_accessibility_outcome_record_policy_v1"; SCHEMA_VERSION="v292"; SOURCE_ID="runtime-accessibility-outcome-record-policy"; CONTRACT_ID="runtime-accessibility-presentation"; OPEN_REVIEW_STATUSES={"pending","not_performed","in_progress","failed"}; RECORD_STATUSES={"planned","pending","not_performed"}; EVIDENCE_KINDS={"log","image","report","video"}; SHA256=re.compile(r"^[0-9a-f]{64}$")
OUTCOME_POLICY={"sequence":["declare_scope","list_outcomes","mark_gates","defer_outcome"],"artifact_types":["validator","test","manifest","evidence"],"outcome_states":["prepared","pending_review","deferred"],"outcome_fields":["accessibility","captions","audio","bindings","camera"],"missing_artifact":"mark_incomplete_without_claim","secret_logging":"never"}; BINDING={"source_schema":SOURCE_SCHEMA,"source_id":SOURCE_ID,"contract_id":CONTRACT_ID,"policy_mode":"exact","apply_rule":"provenance_outcome_only","human_gate":"open","native_policy":"not_run"}; AUTHORITY={"presentation_only":True,"outcome_record_authority":False,"settings_read_authority":False,"settings_write_authority":False,"audio_authority":False,"caption_queue_authority":False,"gameplay_authority":False,"network_authority":False}
def _text(v:Any)->bool:return isinstance(v,str) and bool(v.strip())
def _evidence(v:Any,e:list[str])->None:
 if v is None:return
 if not isinstance(v,list) or not v:e.append("evidence must be null or a non-empty list");return
 for i,x in enumerate(v):
  p=f"evidence[{i}]"
  if not isinstance(x,dict):e.append(f"{p} must be an object");continue
  if not isinstance(x.get("kind"),str) or x.get("kind") not in EVIDENCE_KINDS:e.append(f"{p}.kind must be log, image, report, or video")
  if not _text(x.get("path")):e.append(f"{p}.path must be non-empty text")
  d=x.get("sha256")
  if not isinstance(d,str) or not SHA256.fullmatch(d):e.append(f"{p}.sha256 must be a lowercase 64-character digest")
def validate_runtime_outcome_record_provenance(v:Any)->list[str]:
 if not isinstance(v,dict):return ["runtime outcome-record provenance record must be an object"]
 e=[]
 for k,x in (("schema",SCHEMA),("source_schema",SOURCE_SCHEMA),("schema_version",SCHEMA_VERSION)):
  if v.get(k)!=x:e.append(f"{k} must be {x}")
 for k in ("source_revision","reviewer_required","open_gate_reason"):
  if not _text(v.get(k)):e.append(f"{k} must be non-empty text")
 if v.get("human_review_status") not in OPEN_REVIEW_STATUSES:e.append("human_review_status must remain pending, not_performed, in_progress, or failed")
 if v.get("native_render_status")!="not_run":e.append("native_render_status must remain not_run")
 for k in ("human_review_performed","native_render_performed","policy_verified","runtime_claimed","outcome_written","outcome_confirmed"):
  if v.get(k) is not False:e.append(f"{k} must be false")
 if v.get("outcome_policy")!=OUTCOME_POLICY:e.append("outcome_policy must exactly match the v292 outcome-record policy")
 if v.get("binding")!=BINDING:e.append("binding must exactly match the v292 outcome, human, and native policy")
 if v.get("authority")!=AUTHORITY:e.append("authority must exactly match the presentation-only/outcome boundary")
 for k,x in AUTHORITY.items():
  if v.get(k) is not x:e.append(f"{k} must be {str(x).lower()}")
 for k,x in (("source_id",SOURCE_ID),("contract_id",CONTRACT_ID),("provenance_source_of_truth","runtime_accessibility_outcome_record_policy")):
  if v.get(k)!=x:e.append(f"{k} must be {x}")
 if v.get("status") not in RECORD_STATUSES:e.append("status must remain planned, pending, or not_performed")
 _evidence(v.get("evidence"),e);return e
def validate(path:str|Path)->list[str]:
 try:v=json.loads(Path(path).read_text(encoding="utf-8"))
 except (OSError,json.JSONDecodeError) as x:return [f"runtime outcome-record provenance unreadable: {x}"]
 return validate_runtime_outcome_record_provenance(v)
def main(argv:list[str]|None=None)->int:
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("provenance",type=Path);a=p.parse_args(argv);e=validate(a.provenance)
 if e:print("ACCESSIBILITY_RUNTIME_OUTCOME_RECORD_PROVENANCE_V292_INVALID");print("\n".join(f"- {x}" for x in e));return 1
 print("ACCESSIBILITY_RUNTIME_OUTCOME_RECORD_PROVENANCE_V292_READY: review and native gates remain open");return 0
if __name__=="__main__":raise SystemExit(main())
