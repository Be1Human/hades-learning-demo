extends ActorVisual
## Transform-driven presentation for the authored skull mesh, not skeletal clips.
## The enemy owns facing, its 1.35 m hover anchor, collisions and all action clocks.
const DEFAULT_MODEL := "res://assets/characters/skull-r01/skull.glb"
const BONE_SHADER = preload("res://shaders/skull_bone.gdshader")
const INK_SHADER = preload("res://shaders/character_ink.gdshader")
const WINDUP_SECONDS := 0.55
const RUSH_SECONDS := 0.28

var jaw: Node3D
var bone_materials: Array[ShaderMaterial] = []
var ember_materials: Array[ShaderMaterial] = []
var _model_rest := Transform3D.IDENTITY
var _jaw_rest := Transform3D.IDENTITY
var _hover_time := 0.0
var _motion_speed := 1.0
var _pose_state := ""
var _state_time := 0.0
var _offset := Vector3.ZERO
var _tilt := Vector3.ZERO
var _jaw_angle := 0.0
var _entry_offset := Vector3.ZERO
var _entry_tilt := Vector3.ZERO
var _entry_jaw := 0.0


func configure(path: String, enemy := false) -> void:
	is_enemy = enemy
	# Do not call ActorVisual.configure: it attaches a humanoid weapon and assumes
	# a skeleton. The skull only needs its own mesh and authored jaw pivot.
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	model = null
	jaw = null
	skeleton = null
	anim = null
	weapon = null
	trail_tip = null
	meshes.clear()
	animation_names.clear()
	bone_materials.clear()
	ember_materials.clear()
	_hover_time = 0.0
	_pose_state = ""
	_state_time = 0.0
	_offset = Vector3.ZERO
	_tilt = Vector3.ZERO
	_jaw_angle = 0.0
	var asset_path := DEFAULT_MODEL if path.is_empty() else path
	if not ResourceLoader.exists(asset_path):
		push_error("Skull visual model missing: " + asset_path)
		return
	var packed := load(asset_path) as PackedScene
	if packed == null:
		push_error("Skull visual resource is not a scene: " + asset_path)
		return
	model = packed.instantiate() as Node3D
	if model == null:
		push_error("Skull visual scene must have a Node3D root: " + asset_path)
		return
	add_child(model)
	_model_rest = model.transform
	_collect(model)
	jaw = model.find_child("JawPivot", true, false) as Node3D
	if jaw != null:
		_jaw_rest = jaw.transform
	else:
		push_warning("Skull model has no JawPivot; whole-head presentation remains available.")
	_apply_painted_materials()
	# Imported animation players are intentionally unused: these are mesh poses.
	if anim != null:
		anim.stop()
		anim.active = false
	play("idle")
	set_combat_pose("idle", 0.0, false, 0.0)


func _surface_kind(part: MeshInstance3D, source: Material) -> String:
	var label := String(part.name).to_lower()
	var ancestor: Node = part.get_parent()
	while ancestor != null and ancestor != model:
		label += " " + String(ancestor.name).to_lower()
		ancestor = ancestor.get_parent()
	if source != null:
		label += " " + source.resource_name.to_lower()
	for token in ["ember", "eye_glow", "eyeglow", "glowing_eye"]:
		if token in label:
			return "ember"
	for token in ["cavity", "socket", "nasal", "void", "ink", "crack"]:
		if token in label:
			return "cavity"
	return "bone"


func _apply_painted_materials() -> void:
	for part in meshes:
		if part.mesh == null:
			continue
		# Layer 1 receives room lamps; layer 2 receives the existing actor fill.
		part.layers = 3
		for surface in range(part.mesh.get_surface_count()):
			var source := part.get_active_material(surface)
			var kind := _surface_kind(part, source)
			var paint := ShaderMaterial.new()
			paint.shader = BONE_SHADER
			paint.resource_name = "Skull_" + kind
			var tint := Color.WHITE
			if source is BaseMaterial3D:
				tint = source.albedo_color
				paint.set_shader_parameter("use_texture", source.albedo_texture != null)
				if source.albedo_texture != null:
					paint.set_shader_parameter("albedo_texture", source.albedo_texture)
			paint.set_shader_parameter("base_tint", tint)
			paint.set_shader_parameter("readability_light", 0.18 if kind == "bone" else 0.025)
			paint.set_shader_parameter("ink_strength", 0.18 if kind == "bone" else 0.06)
			paint.set_shader_parameter("paint_exposure", 1.04 if kind == "bone" else 0.90)
			if kind == "ember":
				paint.set_shader_parameter("readability_light", 0.0)
				paint.set_shader_parameter("ink_strength", 0.0)
				paint.set_shader_parameter("emission_strength", 1.1)
				ember_materials.append(paint)
			else:
				var outline := ShaderMaterial.new()
				outline.shader = INK_SHADER
				outline.set_shader_parameter("outline_pixels", 0.55 if kind == "bone" else 0.35)
				paint.next_pass = outline
			part.set_surface_override_material(surface, paint)
			bone_materials.append(paint)


func play(name: String, speed := 1.0, _blend := 0.06) -> void:
	clip = name
	_motion_speed = clampf(speed, 0.25, 3.0) if name in ["idle", "run"] else 1.0
	if name in ["hurt", "death"]:
		set_combat_pose(name, 0.0, false, 0.0)


func set_motion(name: String, speed := 1.0) -> void:
	if clip != name:
		play(name, speed)


func seek_action(name: String, seconds: float) -> void:
	# Compatibility with the inherited enemy call. Its club clock scales a skull
	# windup from 0.55 to 0.62 s. The final set_combat_pose call uses the real clock.
	clip = name
	if name == "club_attack":
		set_combat_pose("attack", seconds * WINDUP_SECONDS / 0.62, seconds >= 0.62, 0.0)
	elif name in ["hurt", "death"]:
		set_combat_pose(name, seconds, false, 0.0)


func flash(amount: float, armor := false) -> void:
	var intensity := clampf(amount / 0.075, 0.0, 1.0)
	var color := Color("90c7e8") if armor else Color("ffca85")
	for material in bone_materials:
		material.set_shader_parameter("flash_amount", intensity)
		material.set_shader_parameter("flash_color", color)


func set_combat_pose(state: String, clock: float, attack_applied: bool, delta: float) -> void:
	if not is_instance_valid(model):
		return
	var step := maxf(delta, 0.0)
	# This oscillator never uses the AI clock, which resets on attacks/recovery.
	_hover_time += step * _motion_speed
	if state != _pose_state:
		_pose_state = state
		_state_time = 0.0
		_entry_offset = _offset
		_entry_tilt = _tilt
		_entry_jaw = _jaw_angle
	_state_time += step
	var age := maxf(clock, 0.0)
	var target_offset := Vector3(0.0, sin(_hover_time * 2.25) * 0.045, 0.0)
	var target_tilt := Vector3(sin(_hover_time * 1.7) * 0.014, 0.0, sin(_hover_time * 1.1) * 0.018)
	var target_jaw := 0.04 + sin(_hover_time * 1.5) * 0.016
	var ember_strength := 1.02 + sin(_hover_time * 2.8) * 0.08
	match state:
		"attack":
			if not attack_applied:
				var charge := smoothstep(0.0, WINDUP_SECONDS, age)
				# +Z faces forward. Negative X pitch raises the snout/chin.
				target_offset = Vector3(0.0, 0.015 + charge * 0.045, -0.16 * charge)
				target_tilt = Vector3(lerpf(-0.035, -0.24, charge), 0.0, 0.012 * sin(_hover_time * 9.0) * charge)
				target_jaw = lerpf(0.055, 0.012, charge)
				ember_strength = 1.10 + charge * 0.50
			else:
				var rush := smoothstep(0.0, 0.055, maxf(age - WINDUP_SECONDS, 0.0))
				target_offset = Vector3(0.0, lerpf(0.045, -0.045, rush), lerpf(-0.16, 0.09, rush))
				target_tilt = Vector3(lerpf(-0.24, 0.19, rush), 0.0, 0.0)
				target_jaw = 0.008
				ember_strength = 1.45
		"recover":
			var settle := smoothstep(0.0, 0.40, age)
			target_offset = _entry_offset.lerp(target_offset, settle)
			target_tilt = _entry_tilt.lerp(target_tilt, settle)
			target_jaw = lerpf(_entry_jaw, target_jaw, settle)
		"hurt":
			var recoil := sin(clampf(age / 0.28, 0.0, 1.0) * PI)
			target_offset += Vector3(0.0, recoil * 0.045, -recoil * 0.13)
			target_tilt += Vector3(-recoil * 0.22, 0.0, recoil * 0.075)
			target_jaw += recoil * 0.16
		"death":
			var fall := smoothstep(0.0, 0.58, age)
			target_offset = _entry_offset.lerp(Vector3(0.035, -0.83, 0.12), fall)
			target_tilt = _entry_tilt.lerp(Vector3(0.82, 0.08, 1.02), fall)
			target_jaw = lerpf(_entry_jaw, 0.62, smoothstep(0.0, 0.33, age))
			ember_strength = lerpf(1.0, 0.08, smoothstep(0.0, 0.48, age))
			# Base enemy dead ticks skip flash(), so release the lethal-hit flash here.
			flash(maxf(0.075 - age, 0.0))
		_:
			if clip == "run":
				target_tilt.x += 0.045
			# Blend out of a previous reaction without resetting the hover phase.
			if _state_time < 0.10 and step > 0.0:
				var settle := smoothstep(0.0, 0.10, _state_time)
				target_offset = _entry_offset.lerp(target_offset, settle)
				target_tilt = _entry_tilt.lerp(target_tilt, settle)
				target_jaw = lerpf(_entry_jaw, target_jaw, settle)
	_offset = target_offset
	_tilt = target_tilt
	_jaw_angle = target_jaw
	model.transform = Transform3D(_model_rest.basis * Basis.from_euler(_tilt), _model_rest.origin + _offset)
	if is_instance_valid(jaw):
		# The asset's JawPivot must be at the actual hinge. No mesh-center rotation.
		jaw.transform = Transform3D(_jaw_rest.basis * Basis(Vector3.RIGHT, _jaw_angle), _jaw_rest.origin)
	for material in ember_materials:
		material.set_shader_parameter("emission_strength", ember_strength)
