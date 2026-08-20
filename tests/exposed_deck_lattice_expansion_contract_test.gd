extends SceneTree

const CONTRACT_SCRIPT := preload("res://scripts/world/exposed_deck_lattice_expansion_contract.gd")
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := CONTRACT_SCRIPT.new()
	var report := contract.get_report()
	_check(bool(report.valid), "default expansion catalog is valid")
	_check(int(report.schema_version) == 1 and int(report.proposal_count) == 3, "report freezes schema and proposal count")
	_check(int(report.live_adjacency_edge_count) == 0, "proposal ledger publishes no live adjacency edges")
	_check(contract.can_implement(&"north-observation-comb"), "only explicitly modern proposal is implementable")
	_check(not contract.can_implement(&"habitat-room-link"), "unknown relationship stays blocked")
	_check(not contract.can_implement(&"freight-branch-continuation"), "unregistered inferred branch stays blocked")
	var proposals := contract.get_proposals()
	_check((proposals[0] as Dictionary).adjacency_claim == false, "modern proposal has no adjacency claim")
	_check((proposals[0] as Dictionary).source_references.is_empty(), "modern proposal carries no invented source reference")
	(proposals[0] as Dictionary)["adjacency_claim"] = true
	_check(bool(contract.validate_catalog(proposals).valid) == false, "mutated adjacency claim is rejected")
	var detached := contract.get_report()
	(detached.proposals[0] as Dictionary)["proposal_id"] = &"mutation"
	_check(StringName((contract.get_report().proposals[0] as Dictionary).proposal_id) == &"north-observation-comb", "reports are deeply detached")
	var malformed := contract.get_proposals()
	(malformed[0] as Dictionary)["source_bounded"] = true
	_check(not bool(contract.validate_catalog(malformed).valid), "source-bounded status without a registered anchor is rejected")
	if _failures.is_empty():
		print("EXPOSED_DECK_LATTICE_EXPANSION_CONTRACT_TEST_PASS: 12 assertions")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
