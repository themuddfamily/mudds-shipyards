class_name EmberMoonStreamingProductionBinding
extends PlanetaryStreamingProductionBinding

## Production caller-physics adapter for [EmberMoonStreamingBootstrap].
##
## Everything this adapter does — encoding one detached caller sample into the
## bootstrap's absolute frame, previewing an origin shift for the common-world
## owner, and reconciling the committed transaction — is identical for every
## streamed body and now lives in [PlanetaryStreamingProductionBinding]. What
## remains here is only which body this one observes for.

const DEFAULT_BOOTSTRAP_PATH := NodePath("../EmberMoonStreamingBootstrap")


func _default_bootstrap_path() -> NodePath:
	return DEFAULT_BOOTSTRAP_PATH


func _world_label() -> String:
	return "Ember"


func _expected_world_id() -> StringName:
	return EmberMoonStreamingBootstrap.WORLD_ID


func _bootstrap_is_expected(bootstrap: PlanetaryStreamingBootstrap) -> bool:
	return bootstrap is EmberMoonStreamingBootstrap
