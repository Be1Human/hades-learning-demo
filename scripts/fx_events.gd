class_name CombatFXEvents
extends RefCounted
## Presentation adapter: gameplay supplies actual positions, owners and end points.
## It never deals damage or invents an enemy, reward, or bloodstone resource.
const Catalog = preload("res://scripts/fx_catalog.gd")
var fx: CombatFX
var active: Dictionary = {}
var allowed: Dictionary = {}

func _init(target: CombatFX) -> void:
	fx = target
	for spec in Catalog.entries(): allowed[spec.id] = true

func emit_event(id: String, context: Dictionary = {}) -> Node3D:
	if not is_instance_valid(fx) or not allowed.has(id): return null
	prune()
	var pos: Vector3 = context.get("position",Vector3.ZERO)
	var direction: Vector3 = context.get("direction",Vector3.FORWARD)
	if direction.is_zero_approx(): direction = Vector3.FORWARD
	direction = direction.normalized()
	var owner: Node3D = context.get("owner")
	var handle: Node3D
	var life: float = context.get("duration",0.55)
	var key: String = context.get("channel",id)
	# Channels are supplied per entity; repeated windups replace their old visuals.
	if owner != null: key = str(owner.get_instance_id())+":"+key
	if context.get("replace",true): cancel_channel(key)
	match id:
		"warning": handle = fx.warning(pos,context.get("radius",2.45),life,direction,context.get("arc",2*acos(0.25)),owner)
		"charge": handle = fx.charge(pos,CombatFX.GOLD)
		"witch_cast": handle = fx.witch_cast(pos,direction,life)
		"skull_warning": handle = fx.skull_warning(pos,direction,life,owner)
		"skull_rush": handle = fx.skull_rush(pos,direction)
		"projectile": handle = fx.projectile(pos,context.get("target",pos+direction*5),context.get("duration",0.8),true)
		"reflected_projectile": handle = fx.reflected_projectile(pos,context.get("target",pos-direction*4),context.get("duration",0.5))
		"stone_cast","stone_pickup","stone_drop","stone_embedded": handle = fx.bloodstone(pos,id.trim_prefix("stone_"),context.get("target",pos+direction*3),owner)
		"brazier_fire","underworld_motes": handle = fx.ambient(pos,id,context.get("persistent",true))
		_:
			if id.begins_with("boss_warning_"): handle = fx.boss_warning(pos,direction,id.trim_prefix("boss_warning_"),life)
			else: Catalog.play(fx,id,pos,direction,context.get("visual"))
	if handle != null:
		active[key] = weakref(handle)
		if id == "stone_embedded" and context.get("persistent",true):
			for effect in fx.effects:
				if effect.node == handle or handle.is_ancestor_of(effect.node):
					effect.loop = true
					effect.loop_position = handle.position
					if effect.node == handle: effect.mode = "held"
					else: effect.flow_time = 0.0
		if owner != null:
			for effect in fx.effects:
				if effect.node == handle and not effect.has("follow") and effect.mode != "travel":
					effect.follow = weakref(owner)
					effect.follow_offset = handle.global_position-owner.global_position
	return handle

func cancel_channel(key: String) -> void:
	if active.has(key):
		fx.cancel(active[key].get_ref())
		active.erase(key)

func cancel_owner(owner: Node3D) -> void:
	if not is_instance_valid(owner): return
	var prefix := str(owner.get_instance_id())+":"
	for key: String in active.keys():
		if key.begins_with(prefix): cancel_channel(key)

func prune() -> void:
	for key in active.keys():
		if not is_instance_valid(active[key].get_ref()): active.erase(key)

func reset() -> void:
	active.clear()
	if is_instance_valid(fx): fx.clear()
