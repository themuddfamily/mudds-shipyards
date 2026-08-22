"""Bounded package source provenance validator v424."""
from __future__ import annotations
import argparse,json
from pathlib import Path
SCHEMA_VERSION=424
def validate_v424(v):
 e=[]
 if not isinstance(v,dict):return ["record must be an object"]
 if v.get("schema_version")!=SCHEMA_VERSION:e.append("schema_version must be 424")
 for k in ("build_label","source_id","source_commit","source_hash","package_version","authorization_attestation_id","authorization_attestation_digest"):
  if not isinstance(v.get(k),str) or not v[k].strip():e.append(f"{k} is required")
 for k in ("source_artifact_hash_count","package_artifact_hash_count","authorization_attestation_entry_count"):
  if not isinstance(v.get(k),int) or isinstance(v[k],bool) or v[k]<0:e.append(f"{k} must be a non-negative integer")
 s=v.get("source");a=v.get("authorization_attestation")
 for n,x in (("source",s),("authorization_attestation",a)):
  if not isinstance(x,dict):e.append(f"{n} must be an object")
  elif x.get("status")=="PASS" and not isinstance(x.get("evidence"),str):e.append(f"{n}.evidence is required")
 if isinstance(s,dict) and s.get("status")=="PASS":
  for k in ("source_id","source_commit","source_hash","package_version","source_artifact_hash_count","package_artifact_hash_count","authorization_attestation_id","authorization_attestation_digest","authorization_attestation_entry_count"):
   if s.get(k)!=v.get(k):e.append(f"source.{k} must match {k}")
  if s.get("identified") is not True:e.append("source.identified must be true")
 if isinstance(a,dict) and a.get("status")=="PASS":
  for k in ("authorization_attestation_id","authorization_attestation_digest","source_hash","package_artifact_hash_count","authorization_attestation_entry_count"):
   if a.get(k)!=v.get(k):e.append(f"authorization_attestation.{k} must match {k}")
  if a.get("authorized") is not True:e.append("authorization_attestation.authorized must be true")
 for n in ("native_execution","hardware_execution","human_review"):
  g=v.get(n)
  if not isinstance(g,dict) or g.get("status") not in {"PASS","FAIL","NOT_RUN","UNKNOWN"}:e.append(f"{n}.status is invalid")
  elif g.get("status")=="NOT_RUN":
   for k in ("evidence","platform","hardware","reviewer","evidence_path"):
    if g.get(k) is not None:e.append(f"{n}.{k} must be null when status is NOT_RUN")
 return e
def main(argv=None):
 p=argparse.ArgumentParser();p.add_argument("record",type=Path);e=validate_v424(json.loads(p.parse_args(argv).record.read_text()))
 if e:print("SOURCE_HASH_PROVENANCE_V424_INVALID");print("\n".join(f"- {x}" for x in e));return 1
 print("SOURCE_HASH_PROVENANCE_V424_VALID");return 0
if __name__=="__main__":raise SystemExit(main())
