class_name ExposedDeckLatticeExpansionContract
extends RefCounted

## Evidence gate for future exposed-deck/lattice additions.
##
## This is a proposal ledger, not a topology registry or a geometry builder.
## A proposal may describe a useful modern interpretation, but it cannot turn
## an unanchored relationship into a live adjacency edge.  Production modules
## remain the only owners of walkable geometry and route authority.

const SCHEMA_VERSION := 1
const CONTENT_CLASS_NEW: StringName = &"NEW"
const EVIDENCE_MODERN: StringName = &"modern_interpretation"
const EVIDENCE_UNKNOWN: StringName = &"unknown"
const SOURCE_BOUNDED_STATUSES := [&"observed", &"inferred", &"fixed_era_inspired"]

static func _catalog() -> Array[Dictionary]:
	return [
	{
		"proposal_id": &"north-observation-comb",
		"label": &"new",
		"evidence_status": EVIDENCE_MODERN,
		"content_class": CONTENT_CLASS_NEW,
		"source_bounded": false,
		"source_references": PackedStringArray(),
		"adjacency_claim": false,
		"implementation_gate": &"modern_interpretation_only",
		"unknowns": PackedStringArray(["exact placement", "function", "relationship to existing spine"]),
	},
	{
		"proposal_id": &"habitat-room-link",
		"label": &"unknown",
		"evidence_status": EVIDENCE_UNKNOWN,
		"content_class": CONTENT_CLASS_NEW,
		"source_bounded": false,
		"source_references": PackedStringArray(),
		"adjacency_claim": false,
		"implementation_gate": &"blocked_pending_external_evidence",
		"unknowns": PackedStringArray(["room identity", "connection", "elevation"]),
	},
	{
		"proposal_id": &"freight-branch-continuation",
		"label": &"inferred",
		"evidence_status": EVIDENCE_UNKNOWN,
		"content_class": CONTENT_CLASS_NEW,
		"source_bounded": false,
		"source_references": PackedStringArray(),
		"adjacency_claim": false,
		"implementation_gate": &"blocked_pending_registered_anchor",
		"unknowns": PackedStringArray(["continuity", "branch endpoint", "historical era"]),
	},
	]


func get_proposals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for proposal in _catalog():
		result.append((proposal as Dictionary).duplicate(true))
	return result


func get_proposal(proposal_id: StringName) -> Dictionary:
	for proposal in _catalog():
		if StringName((proposal as Dictionary).proposal_id) == proposal_id:
			return (proposal as Dictionary).duplicate(true)
	return {}


func can_implement(proposal_id: StringName) -> bool:
	var proposal: Dictionary = get_proposal(proposal_id)
	return not proposal.is_empty() and StringName(proposal.implementation_gate) == &"modern_interpretation_only"


func validate_catalog(proposals: Array = get_proposals()) -> Dictionary:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for raw in proposals:
		if not (raw is Dictionary):
			errors.append("proposal is not a dictionary")
			continue
		var proposal := raw as Dictionary
		var proposal_id := StringName(proposal.get("proposal_id", &""))
		if proposal_id.is_empty() or seen.has(proposal_id):
			errors.append("proposal ids must be non-empty and unique")
		seen[proposal_id] = true
		var status := StringName(proposal.get("evidence_status", &""))
		var source_bounded := bool(proposal.get("source_bounded", false))
		var references: Variant = proposal.get("source_references", PackedStringArray())
		if not (references is PackedStringArray):
			errors.append("%s has malformed source references" % proposal_id)
			continue
		if source_bounded and (references as PackedStringArray).is_empty():
			errors.append("%s is source-bounded without a registered source reference" % proposal_id)
		if status in SOURCE_BOUNDED_STATUSES and not source_bounded:
			errors.append("%s uses a source-bounded status without source support" % proposal_id)
		if bool(proposal.get("adjacency_claim", false)) and not source_bounded:
			errors.append("%s claims adjacency without source-bounded evidence" % proposal_id)
		if bool(proposal.get("adjacency_claim", false)):
			errors.append("%s may not publish live adjacency from the expansion ledger" % proposal_id)
		if StringName(proposal.get("content_class", &"")) != CONTENT_CLASS_NEW:
			errors.append("%s must remain NEW until separately reviewed" % proposal_id)
		if StringName(proposal.get("implementation_gate", &"")) == &"approved_live_adjacency":
			errors.append("%s attempts to bypass the route registry" % proposal_id)
	return {"valid": errors.is_empty(), "errors": errors, "proposal_count": proposals.size()}


func get_report() -> Dictionary:
	var proposals := get_proposals()
	var validation := validate_catalog(proposals)
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": bool(validation.valid),
		"errors": (validation.errors as PackedStringArray).duplicate(),
		"proposal_count": proposals.size(),
		"implementable_modern_proposals": ["north-observation-comb"],
		"live_adjacency_edge_count": 0,
		"proposals": proposals,
		"content_note": "Proposals are NEW modern interpretations; no unregistered adjacency is asserted.",
	}
