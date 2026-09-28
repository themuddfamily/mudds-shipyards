class_name PlanetaryAtmosphereFlightEffects
extends RefCounted

## What flying through a real atmosphere does to the player's craft and ears.
##
## GameFlow advances this once per physics tick. While a streamed world with a
## configured [PlanetaryAtmosphereComposition] is resident (Aurora today; never
## airless Ember, which composes no atmosphere), it:
##
## 1. Entry heat / compression. Attaches one generic, collision-anchored
##    compression envelope ([HeroAtmosphericEntryEnvelopeBinding] under
##    [constant ENVELOPE_NAME]) to whichever of the nine flyable craft is active,
##    the Arrow included. Intensity is the sampler's density x speed entry model
##    ([method PlanetaryAtmosphereSampler._entry_effect_intensity]). Reduced
##    flash caps the envelope to a steady low-opacity cue. The Arrow's own heat
##    overlay is deliberately left alone: its adapter's configuration is
##    permanent, and a configured target is what makes the Arrow's Ember-owned
##    presenter treat a later descent as atmospheric, so configuring it for
##    Aurora would light plasma over airless Ember.
## 2. Weather wind response. Below a wind ceiling, a piloted craft in ordinary
##    flight receives a bounded lateral drift/buffet from the authored wind
##    vector, submitted through [method HeroShip.submit_atmospheric_wind_drift].
##    Landed, berthed, landing-assist and cruise states are exactly zero. The
##    same wind vector moves the cloud shell (via the source's weather clock).
## 3. Interior/exterior audio. A smoothed interior blend (sealed cockpit, open
##    canopy, walkable cabin, outside) cross-fades the world's exterior and cabin
##    ambience and low-passes the exterior while inside, replacing the old
##    seated/on-foot hard switch. Wind audio strength follows the gusting wind.
##
## Every attachment is released when the atmosphere world unloads, the craft is
## destroyed or replaced, or the whole Main subtree leaves the tree
## ([method reset]). The model, units and trade-offs are documented in
## docs/PLANETARY_ATMOSPHERE_MODEL.md. This object owns no flight, landing,
## damage, streaming or weather authority.

const COMPONENT_ID: StringName = &"planetary-atmosphere-flight-effects"
## Envelope node name, distinct from the Ember surface loop's fleet envelope so
## the two owners can never collide on one craft.
const ENVELOPE_NAME: StringName = &"PlanetaryAtmosphereEntryEnvelope"
const EnvelopeBindingScript := preload(
	"res://scripts/ships/hero_atmospheric_entry_envelope_binding.gd"
)
const SamplerScript := preload(
	"res://scripts/world/planetary_atmosphere_sampler.gd"
)

## Physics ticks to wait before retrying a refused envelope attachment.
const ENTRY_ATTACH_RETRY_TICKS := 30

## Fraction of the lateral wind speed a craft drifts at (unitless).
const WIND_COUPLING_UNITLESS := 0.5
## Hard bound on the drift this component submits (m/s). HeroShip clamps again.
const WIND_DRIFT_MAX_MPS := 6.0
## The wind is full strength up to the cloud top, then fades to zero at the
## cloud top plus this band (m), never above the atmosphere top.
const WIND_CEILING_BAND_M := 3_000.0
## First-order response time of the drift toward its target (s).
const WIND_RESPONSE_SECONDS := 0.8
## Gust amplitude: base plus a share of the effective weather intensity.
const WIND_GUST_BASE_UNITLESS := 0.25
const WIND_GUST_WEATHER_UNITLESS := 0.35
## Cross-wind buffet amplitude as a share of the gusting lateral wind.
const WIND_BUFFET_CROSS_UNITLESS := 0.18
## Reduced motion keeps the steady drift but calms the gust/buffet oscillation.
const WIND_REDUCED_MOTION_GUST_SCALE := 0.35
## Wind speed that reads as full-strength exterior wind audio (m/s).
const WIND_AUDIO_REFERENCE_MPS := 12.0

## Target interior blends (0 = outside, 1 = sealed cabin).
const INTERIOR_BLEND_SEALED_COCKPIT := 1.0
const INTERIOR_BLEND_OPEN_CANOPY := 0.45
const INTERIOR_BLEND_WALKABLE_CABIN := 0.8
## A full outside<->sealed cross-fade takes this long (s).
const INTERIOR_CROSSFADE_SECONDS := 1.1
## Moving-interior membership marker published on the Player by
## MovingInteriorFrame.
const MOVING_INTERIOR_OWNER_META: StringName = &"_moving_interior_frame_owner"

## The weather clock wraps well inside the cloud presenter's offset bound.
const WEATHER_CLOCK_MAX_WRAP_SECONDS := 86_400.0
const CLOUD_WIND_OFFSET_BUDGET_M := 900_000.0

var _active := false
var _source_ref: WeakRef
var _loaded_ref: WeakRef
var _loaded_instance_id := 0
var _profile: PlanetaryAtmosphereProfile
var _profile_id: StringName = &""
var _sampler: PlanetaryAtmosphereSampler
var _body_radius_m := 0.0
var _weather_scalar := 1.0
var _cloud_top_m := 0.0
var _atmosphere_top_m := 0.0
var _weather_clock_seconds := 0.0
var _weather_clock_wrap_seconds := WEATHER_CLOCK_MAX_WRAP_SECONDS

var _entry_binding: RefCounted
var _entry_ship_ref: WeakRef
var _entry_ship_instance_id := 0
var _entry_attach_cooldown := 0
var _entry_intensity := 0.0
var _entry_presented_once := false
## Whether the envelope still shows anything (segments or its timed
## entry-recovery hold) after the last presentation.
var _entry_envelope_visible := false
var _last_entry_result: Dictionary = {}

var _wind_drift_body_mps := Vector3.ZERO
var _last_wind_drift_world_mps := Vector3.ZERO
var _last_wind_body_mps := Vector3.ZERO
var _wind_strength_unitless := -1.0
var _wind_eligible := false

var _interior_blend := -1.0
var _interior_target := 0.0

var _last_altitude_m := -1.0
var _last_speed_mps := 0.0
var _tick_count := 0
var _reset_count := 0
var _last_reset_reason: StringName = &"never_active"


## One physics tick. [param craft] is the active craft (or null),
## [param piloting] whether the player is flying it, [param player] the local
## pilot, [param hud] the accessibility source, [param sources] candidate
## streaming bootstraps (anything exposing get_atmosphere_composition() and
## get_loaded_instance()).
func advance(
		delta: float, craft: HeroShip, piloting: bool, player: Node3D,
		hud: GameHUD, sources: Array
	) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	var resolved := _resolve_atmosphere(sources)
	if resolved.is_empty():
		if _active:
			reset(&"atmosphere_world_not_resident")
		return
	if not _bind_atmosphere(resolved):
		if _active:
			reset(&"atmosphere_profile_unusable")
		return
	_active = true
	_tick_count += 1
	var loaded := resolved.loaded as Node3D
	var source := resolved.source as Object
	var wind_speed_for_wrap := maxf(
		(_profile.wind_velocity_mps * _weather_scalar).length(), 0.001
	)
	_weather_clock_wrap_seconds = minf(
		WEATHER_CLOCK_MAX_WRAP_SECONDS,
		CLOUD_WIND_OFFSET_BUDGET_M / wind_speed_for_wrap
	)
	_weather_clock_seconds = fposmod(
		_weather_clock_seconds + delta, _weather_clock_wrap_seconds
	)
	var accessibility := hud.get_accessibility_report() \
		if hud != null and is_instance_valid(hud) \
			and hud.has_method(&"get_accessibility_report") else {}
	var reduced_motion := bool(accessibility.get("reduced_motion", false))

	var live_craft: HeroShip = craft
	if live_craft != null and (not is_instance_valid(live_craft) \
			or not live_craft.is_inside_tree() \
			or live_craft.is_queued_for_deletion() or live_craft.is_destroyed()):
		live_craft = null
	var live_player: Node3D = player if player != null \
		and is_instance_valid(player) and player.is_inside_tree() else null
	# Entry heat and drift are measured at the craft. The wind the listener
	# hears is measured at the craft while it is flown and at the pilot on foot.
	var craft_body_local := loaded.to_local(live_craft.global_position) \
		if live_craft != null else Vector3.INF
	var observer: Node3D = live_craft if piloting or live_player == null \
		else live_player
	var body_local := Vector3.INF
	var altitude_m := -1.0
	if observer != null:
		body_local = craft_body_local if observer == live_craft \
			else loaded.to_local(observer.global_position)
		if body_local.is_finite():
			altitude_m = maxf(0.0, body_local.length() - _body_radius_m)
	_last_altitude_m = altitude_m

	_update_entry(live_craft, hud, craft_body_local)
	var wind_sample := _sample_wind(altitude_m, body_local, reduced_motion)
	_update_wind_drift(live_craft, piloting, loaded, wind_sample, delta)
	_update_interior_blend(player, live_craft, delta)
	if source != null and source.has_method(&"set_surface_atmosphere_state"):
		source.call(
			&"set_surface_atmosphere_state",
			_smoothed_interior_blend(),
			_wind_strength_unitless,
			_weather_clock_seconds,
		)


## Releases every attachment and returns to the inactive state. Safe to call
## repeatedly, from any lifecycle edge (unload, destruction, whole-Main exit).
func reset(reason: StringName = &"reset") -> void:
	_detach_entry(reason)
	_entry_attach_cooldown = 0
	var source := _source_ref.get_ref() as Object if _source_ref != null else null
	if source != null and is_instance_valid(source) \
			and source.has_method(&"clear_surface_atmosphere_state"):
		source.call(&"clear_surface_atmosphere_state")
	_source_ref = null
	_loaded_ref = null
	_loaded_instance_id = 0
	_profile = null
	_profile_id = &""
	_sampler = null
	_body_radius_m = 0.0
	_weather_scalar = 1.0
	_weather_clock_seconds = 0.0
	_wind_drift_body_mps = Vector3.ZERO
	_last_wind_drift_world_mps = Vector3.ZERO
	_last_wind_body_mps = Vector3.ZERO
	_wind_strength_unitless = -1.0
	_wind_eligible = false
	_interior_blend = -1.0
	_interior_target = 0.0
	_last_altitude_m = -1.0
	_last_speed_mps = 0.0
	if _active:
		_reset_count += 1
	_active = false
	_last_reset_reason = reason


func is_active() -> bool:
	return _active


func get_snapshot() -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"active": _active,
		"profile_id": _profile_id,
		"loaded_instance_id": _loaded_instance_id,
		"altitude_m": _last_altitude_m,
		"speed_mps": _last_speed_mps,
		"weather_clock_seconds": _weather_clock_seconds,
		"weather_scalar": _weather_scalar,
		"entry": {
			"attached": _entry_binding != null,
			"craft_instance_id": _entry_ship_instance_id,
			"intensity_unitless": _entry_intensity,
			"envelope_name": ENVELOPE_NAME,
			"binding": _entry_binding.call(&"get_snapshot") \
				if _entry_binding != null else {"attached": false},
			"last_result": _last_entry_result.duplicate(true),
		},
		"wind": {
			"eligible": _wind_eligible,
			"wind_body_mps": _last_wind_body_mps,
			"drift_body_mps": _wind_drift_body_mps,
			"drift_world_mps": _last_wind_drift_world_mps,
			"strength_unitless": _wind_strength_unitless,
		},
		"audio": {
			"interior_target_unitless": _interior_target,
			"interior_blend_unitless": _interior_blend,
			"smoothed_interior_blend_unitless": _smoothed_interior_blend(),
		},
		"tick_count": _tick_count,
		"reset_count": _reset_count,
		"last_reset_reason": _last_reset_reason,
		"authority": {
			"flight": false, "landing": false, "damage": false,
			"streaming": false, "weather": false, "presentation": true,
			"audio_mix": true,
		},
	}.duplicate(true)


# --- Resolution ---------------------------------------------------------------

func _resolve_atmosphere(sources: Array) -> Dictionary:
	for candidate: Variant in sources:
		# Validity first: a freed instance may not even be type-tested or cast.
		if not is_instance_valid(candidate) or not candidate is Object:
			continue
		var source := candidate as Object
		if not source.has_method(&"get_atmosphere_composition") \
				or not source.has_method(&"get_loaded_instance"):
			continue
		var composition_value: Variant = source.call(&"get_atmosphere_composition")
		var loaded_value: Variant = source.call(&"get_loaded_instance")
		if not is_instance_valid(composition_value) \
				or not is_instance_valid(loaded_value) \
				or not composition_value is PlanetaryAtmosphereComposition \
				or not loaded_value is Node3D:
			continue
		var composition := composition_value as PlanetaryAtmosphereComposition
		var loaded := loaded_value as Node3D
		if not loaded.is_inside_tree() or loaded.is_queued_for_deletion():
			continue
		if composition.atmosphere_profile == null \
				or composition.world_definition == null:
			continue
		return {"source": source, "loaded": loaded, "composition": composition}
	return {}


func _bind_atmosphere(resolved: Dictionary) -> bool:
	var loaded := resolved.loaded as Node3D
	var composition := resolved.composition as PlanetaryAtmosphereComposition
	var source := resolved.source as Object
	var profile := composition.atmosphere_profile
	var same: bool = _sampler != null and _profile == profile \
		and _loaded_instance_id == loaded.get_instance_id() \
		and _source_ref != null and _source_ref.get_ref() == source
	if same:
		return true
	if _active or _sampler != null:
		# A new streamed generation or a different world: nothing from the
		# previous one may survive into it.
		reset(&"atmosphere_generation_replaced")
	var sampler := SamplerScript.new() as PlanetaryAtmosphereSampler
	if not bool(sampler.configure(profile).get("accepted", false)):
		return false
	_sampler = sampler
	_profile = profile
	_profile_id = profile.profile_id
	_source_ref = weakref(source)
	_loaded_ref = weakref(loaded)
	_loaded_instance_id = loaded.get_instance_id()
	_body_radius_m = composition.world_definition.body_radius_metres
	_cloud_top_m = profile.cloud_top_altitude_m
	_atmosphere_top_m = profile.atmosphere_top_altitude_m
	_weather_scalar = clampf(float(source.call(&"get_atmosphere_weather_scalar")), 0.0, 1.0) \
		if source.has_method(&"get_atmosphere_weather_scalar") else 1.0
	return true


# --- Entry heat / compression -----------------------------------------------

func _update_entry(
		craft: HeroShip, hud: GameHUD, body_local: Vector3
	) -> void:
	if craft == null or hud == null or not is_instance_valid(hud):
		_detach_entry(&"craft_unavailable")
		return
	if _entry_binding != null and (
			_entry_ship_instance_id != craft.get_instance_id()
			or _entry_ship_ref == null or _entry_ship_ref.get_ref() != craft):
		_detach_entry(&"craft_replaced")
	if _entry_binding == null:
		if _entry_attach_cooldown > 0:
			_entry_attach_cooldown -= 1
			return
		if not _attach_entry(craft, hud):
			_entry_attach_cooldown = ENTRY_ATTACH_RETRY_TICKS
			return
	if not body_local.is_finite():
		return
	var altitude := clampf(
		body_local.length() - _body_radius_m, 0.0,
		PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M
	)
	var speed := clampf(
		craft.velocity.length() if craft.velocity.is_finite() else 0.0,
		0.0, PlanetaryAtmosphereProfile.MAX_ENTRY_SPEED_MPS
	)
	_last_speed_mps = speed
	var sample := _sampler.sample(altitude, 0.0, speed, 0.0, 0.0)
	var intensity := clampf(
		float(sample.get("entry_effect_intensity", 0.0)), 0.0, 1.0
	) if bool(sample.get("accepted", false)) else 0.0
	# Slow flight low down is the common case: once the envelope has presented
	# zero and shows nothing, keep it there without re-presenting every tick.
	# A hot-to-zero drop arms a timed recovery hold that only counts down on
	# observations, so keep presenting until that cue has run out.
	if _entry_presented_once and intensity == 0.0 and _entry_intensity == 0.0 \
			and not _entry_envelope_visible:
		return
	var presented := _entry_binding.call(
		&"present_observation", altitude, speed, true
	) as Dictionary
	_last_entry_result = presented.duplicate(true)
	if not bool(presented.get("accepted", false)):
		# The craft rebuilt its visual root, or the envelope was freed with it.
		_detach_entry(StringName(presented.get("reason", &"present_rejected")))
		return
	_entry_presented_once = true
	_entry_intensity = intensity
	_entry_envelope_visible = bool(
		((presented.get("snapshot", {}) as Dictionary).get("envelope", {}) \
			as Dictionary).get("visible", false)
	)


func _attach_entry(craft: HeroShip, hud: GameHUD) -> bool:
	var binding := EnvelopeBindingScript.new() as RefCounted
	var attached := binding.call(&"attach", craft, hud, ENVELOPE_NAME) \
		as Dictionary
	if not bool(attached.get("accepted", false)):
		_last_entry_result = attached.duplicate(true)
		return false
	var configured := binding.call(&"configure_atmosphere", _profile) \
		as Dictionary
	if not bool(configured.get("accepted", false)):
		binding.call(&"detach")
		_last_entry_result = configured.duplicate(true)
		return false
	_entry_binding = binding
	_entry_ship_ref = weakref(craft)
	_entry_ship_instance_id = craft.get_instance_id()
	_entry_intensity = 0.0
	_entry_presented_once = false
	_entry_envelope_visible = false
	_last_entry_result = configured.duplicate(true)
	return true


func _detach_entry(reason: StringName) -> void:
	if _entry_binding != null:
		_entry_binding.call(&"detach")
	_entry_binding = null
	_entry_ship_ref = null
	_entry_ship_instance_id = 0
	_entry_intensity = 0.0
	_entry_presented_once = false
	_entry_envelope_visible = false
	if reason != &"":
		_last_entry_result = {"accepted": true, "reason": reason}


# --- Weather wind response ----------------------------------------------------

## Returns the body-frame lateral drift target and the audio wind strength for
## the observer. Everything is a pure function of altitude, position and the
## weather clock, so equal inputs give equal wind on every run.
func _sample_wind(
		altitude_m: float, body_local: Vector3, reduced_motion: bool
	) -> Dictionary:
	if altitude_m < 0.0 or not body_local.is_finite() \
			or body_local.is_zero_approx():
		_wind_strength_unitless = -1.0
		_last_wind_body_mps = Vector3.ZERO
		return {"target_body_mps": Vector3.ZERO}
	var sample := _sampler.sample(
		minf(altitude_m, PlanetaryAtmosphereProfile.MAX_ATMOSPHERE_ALTITUDE_M),
		0.0, 0.0, _weather_scalar, 1.0
	)
	if not bool(sample.get("accepted", false)):
		_wind_strength_unitless = -1.0
		_last_wind_body_mps = Vector3.ZERO
		return {"target_body_mps": Vector3.ZERO}
	var wind := sample.get("wind_velocity_mps", Vector3.ZERO) as Vector3
	var density_ratio := clampf(float(sample.get("density_ratio", 0.0)), 0.0, 1.0)
	var weather_intensity := clampf(float(
		(sample.get("inputs", {}) as Dictionary).get(
			"effective_weather_intensity_unitless", 0.0
		)
	), 0.0, 1.0)
	var up := body_local.normalized()
	var lateral := wind.slide(up)
	var ceiling := minf(_cloud_top_m + WIND_CEILING_BAND_M, _atmosphere_top_m)
	var fade := 1.0
	if altitude_m >= ceiling:
		fade = 0.0
	elif altitude_m > _cloud_top_m and ceiling > _cloud_top_m:
		fade = 1.0 - smoothstep(_cloud_top_m, ceiling, altitude_m)
	var t := _weather_clock_seconds
	var phase := body_local.x * 0.0011 + body_local.z * 0.0007
	var amplitude := (
		WIND_GUST_BASE_UNITLESS + WIND_GUST_WEATHER_UNITLESS * weather_intensity
	) * (WIND_REDUCED_MOTION_GUST_SCALE if reduced_motion else 1.0)
	var gust := maxf(0.0, 1.0 + amplitude * (
		0.6 * sin(1.3 * t + phase) + 0.4 * sin(3.7 * t + 2.0 * phase)
	))
	var cross := Vector3.ZERO
	if lateral.length_squared() > 0.000001:
		cross = up.cross(lateral.normalized()) * lateral.length() \
			* WIND_BUFFET_CROSS_UNITLESS * amplitude * sin(2.9 * t + phase)
	var target := (lateral * gust + cross) * WIND_COUPLING_UNITLESS \
		* sqrt(density_ratio) * fade
	_last_wind_body_mps = wind * gust
	_wind_strength_unitless = clampf(
		wind.length() * gust / WIND_AUDIO_REFERENCE_MPS, 0.0, 1.0
	)
	return {"target_body_mps": target.limit_length(WIND_DRIFT_MAX_MPS)}


func _update_wind_drift(
		craft: HeroShip, piloting: bool, loaded: Node3D,
		wind_sample: Dictionary, delta: float
	) -> void:
	_wind_eligible = craft != null and piloting \
		and craft.is_atmospheric_wind_drift_eligible()
	if not _wind_eligible:
		# Landed, berthed, landing assist, cruise: exactly zero, and the next
		# eligible tick ramps up from rest rather than snapping to full drift.
		_wind_drift_body_mps = Vector3.ZERO
		_last_wind_drift_world_mps = Vector3.ZERO
		return
	var target := wind_sample.get("target_body_mps", Vector3.ZERO) as Vector3
	var response := 1.0 - exp(-delta / WIND_RESPONSE_SECONDS)
	_wind_drift_body_mps = _wind_drift_body_mps.lerp(target, response)
	if _wind_drift_body_mps.length_squared() < 0.000001:
		_last_wind_drift_world_mps = Vector3.ZERO
		return
	var drift_world := (loaded.global_basis * _wind_drift_body_mps) \
		.limit_length(WIND_DRIFT_MAX_MPS)
	if craft.submit_atmospheric_wind_drift(drift_world):
		_last_wind_drift_world_mps = drift_world


# --- Interior / exterior audio -----------------------------------------------

func _update_interior_blend(
		player: Node3D, craft: HeroShip, delta: float
	) -> void:
	var target := 0.0
	if player != null and is_instance_valid(player):
		if player.has_method(&"is_seated") and bool(player.call(&"is_seated")):
			target = INTERIOR_BLEND_SEALED_COCKPIT
			if craft != null and craft.is_canopy_open():
				target = INTERIOR_BLEND_OPEN_CANOPY
		elif _player_in_walkable_interior(player):
			target = INTERIOR_BLEND_WALKABLE_CABIN
	_interior_target = target
	if _interior_blend < 0.0:
		# Arriving (or re-entering) starts in the right place, not mid-fade.
		_interior_blend = target
	else:
		_interior_blend = move_toward(
			_interior_blend, target, delta / INTERIOR_CROSSFADE_SECONDS
		)


func _player_in_walkable_interior(player: Node3D) -> bool:
	if not player.has_meta(MOVING_INTERIOR_OWNER_META):
		return false
	var owner_ref: Variant = player.get_meta(MOVING_INTERIOR_OWNER_META)
	if not owner_ref is WeakRef:
		return false
	var frame_owner: Variant = (owner_ref as WeakRef).get_ref()
	return frame_owner is Node and is_instance_valid(frame_owner) \
		and (frame_owner as Node).is_inside_tree()


## Smoothstep-eased blend: the fade leaves and arrives gently. Negative means no
## blend has been established (the source then falls back to its perspective).
func _smoothed_interior_blend() -> float:
	if _interior_blend < 0.0:
		return -1.0
	var b := clampf(_interior_blend, 0.0, 1.0)
	return b * b * (3.0 - 2.0 * b)
