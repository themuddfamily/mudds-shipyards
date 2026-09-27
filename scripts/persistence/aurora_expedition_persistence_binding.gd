class_name AuroraExpeditionPersistenceBinding
extends "res://scripts/persistence/planetary_surface_visit_persistence_binding.gd"

## Namespaced atomic-store bridge for one interrupted Aurora visit.
##
## The bridge itself is the shared surface-visit binding. Aurora's records keep
## their payload kind, their `aurora_*` reasons and their digest, and Aurora's
## first records - written before the coastal survey existed and so carrying no
## `survey` key - still load, which is why the survey is optional here.

const SurveyType := preload("res://scripts/activities/aurora_coastal_survey.gd")
const PAYLOAD_KIND := "aurora_expedition_active_visit"
const VISIT_KEYS := BASE_VISIT_KEYS


func _init() -> void:
	super("aurora", PAYLOAD_KIND, SurveyType, false)


## Kept for callers that computed Aurora receipts directly.
static func _digest(visit: Dictionary) -> String:
	return digest_visit(visit)
