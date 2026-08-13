class_name PhysicsLayers
extends RefCounted

## Canonical 3D physics-layer contract for gameplay code.
##
## Layer indices mirror `project.godot`. Actor and query masks below describe
## the intended multi-entity foundation; existing scenes can migrate to them a
## component at a time without changing these shared meanings.

const WORLD_INDEX := 1
const PLAYER_INDEX := 2
const SHIP_INDEX := 3
const INTERACTABLE_INDEX := 4
const PROJECTILE_INDEX := 5
const TARGET_INDEX := 6

const WORLD := 1 << (WORLD_INDEX - 1)
const PLAYER := 1 << (PLAYER_INDEX - 1)
const SHIP := 1 << (SHIP_INDEX - 1)
const INTERACTABLE := 1 << (INTERACTABLE_INDEX - 1)
const PROJECTILE := 1 << (PROJECTILE_INDEX - 1)
const TARGET := 1 << (TARGET_INDEX - 1)

const NONE := 0
const SOLID_ACTOR_LAYERS := PLAYER | SHIP
const SOLID_BODY_MASK := WORLD | SOLID_ACTOR_LAYERS
const DAMAGEABLE_LAYERS := PLAYER | SHIP | TARGET
const QUERY_ONLY_LAYERS := INTERACTABLE | TARGET
const ALL_NAMED_LAYERS := (
	WORLD | PLAYER | SHIP | INTERACTABLE | PROJECTILE | TARGET
)

# Body/area matrix. Static world geometry is detected by moving actors, so it
# does not need to monitor anything itself. Player and ship masks are symmetric
# for stable player-player, player-ship, and ship-ship physical interaction.
const WORLD_BODY_LAYER := WORLD
const WORLD_BODY_MASK := NONE
const PLAYER_BODY_LAYER := PLAYER
const PLAYER_BODY_MASK := SOLID_BODY_MASK
const SHIP_BODY_LAYER := SHIP
const SHIP_BODY_MASK := SOLID_BODY_MASK

# Interaction and target volumes are query surfaces rather than solid bodies.
# A ship should expose a child interaction area instead of mixing the
# Interactable bit into its physical body layer.
const INTERACTABLE_AREA_LAYER := INTERACTABLE
const INTERACTABLE_AREA_MASK := NONE
const DAMAGEABLE_TARGET_AREA_LAYER := TARGET
const DAMAGEABLE_TARGET_AREA_MASK := NONE

# Physical projectile bodies can hit geometry or any supported damageable, but
# neither interaction triggers nor other projectiles.
const PROJECTILE_BODY_LAYER := PROJECTILE
const PROJECTILE_BODY_MASK := WORLD | DAMAGEABLE_LAYERS

# Query masks. Hitscan includes both physical actor bodies and optional Target
# child areas so current targets and future component-based hurtboxes coexist.
const INTERACTION_QUERY_MASK := INTERACTABLE
const HITSCAN_QUERY_MASK := WORLD | DAMAGEABLE_LAYERS
const CAMERA_OBSTRUCTION_QUERY_MASK := WORLD | SHIP
const AI_AVOIDANCE_QUERY_MASK := WORLD | SHIP
