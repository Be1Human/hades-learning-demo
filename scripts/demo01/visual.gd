extends ActorVisual
## Uses authored character revisions and mature source clips. No duplicate sword mesh.
const Rules = preload("res://scripts/demo01/rules.gd")
var phase_map: Dictionary = {}
var missing_clips: Array[String] = []
var entry_pose: Array[Transform3D] = []
var entry_blend_seconds := 0.0

func configure(path: String, enemy := false) -> void:
	is_enemy = enemy
	if not ResourceLoader.exists(path):
		push_error("Demo01 character asset is not available: " + path)
		return
	model = load(path).instantiate()
	add_child(model)
	_collect(model)
	_apply_painted_materials()
	flash_material = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.albedo_color = Color(1.0,0.28,0.08,0.85)
	if anim:
		for name in anim.get_animation_list():
			var short_name: String = name.get_slice("/",name.get_slice_count("/")-1)
			animation_names[short_name] = name
			if short_name in ["idle","run"]:
				anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	var manifest_path := "res://assets/characters/demo01/animation-manifest.json"
	if FileAccess.file_exists(manifest_path):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if manifest is Dictionary:
			phase_map = manifest.get("enemy" if enemy else "hero",{}).get("clips",{})
	if skeleton:
		var hand := skeleton.find_bone("RightHand")
		if hand >= 0:
			var attachment := BoneAttachment3D.new()
			attachment.bone_idx = hand
			skeleton.add_child(attachment)
			if enemy:
				weapon = _make_weapon(true)
				attachment.add_child(weapon)
			else:
				# Sword geometry is already weighted into the exported R03 character.
				weapon = Marker3D.new()
				weapon.name = "AuthoredSwordAnchor"
				attachment.add_child(weapon)
				trail_tip = Marker3D.new()
				trail_tip.position = Vector3(0.59701645,0.09516790,0.98864846)
				weapon.add_child(trail_tip)
	play("idle")
	# Bit 2 receives the gentle actor fill; bit 1 retains all physical room lights.
	for part in find_children("*","MeshInstance3D",true,false):part.layers=3

func _make_weapon(_enemy: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "SpikedWoodClub"
	# R05 grip is across the palm, rather than along the extended fingers.
	# The authored club swing uses this socket; trail_tip stays in weapon space.
	root.position = Vector3(0.055, 0.105, -0.17)
	root.rotation.x = PI / 2.0
	var wood := _material(Color("6e3930"))
	var iron := _material(Color("c78958"),0.38)
	var shadow := _material(Color("39262a"))
	var grip := CylinderMesh.new()
	grip.top_radius = .045
	grip.bottom_radius = .045
	grip.height = .73
	grip.radial_segments = 9
	_mesh(root,grip,shadow,Vector3(0,.15,0))
	var head := CylinderMesh.new()
	head.top_radius = .28
	head.bottom_radius = .15
	head.height = .88
	head.radial_segments = 9
	_mesh(root,head,wood,Vector3(0,.80,0))
	for y in [.52,1.07]:
		var band := CylinderMesh.new()
		band.top_radius = .17 + (y-.36)*.148 + .012
		band.bottom_radius = band.top_radius
		band.height = .085
		band.radial_segments = 9
		_mesh(root,band,iron,Vector3(0,y,0))
		for i in range(5):
			var angle := i*TAU/5 + (0.36 if y>1 else 0.0)
			var outward := Vector3(cos(angle),.22,sin(angle)).normalized()
			var spike := CylinderMesh.new()
			spike.top_radius = 0
			spike.bottom_radius = .072
			spike.height = .22
			spike.radial_segments = 4
			var tooth := _mesh(root,spike,iron,Vector3(cos(angle)*band.top_radius,y,sin(angle)*band.top_radius)+outward*.08)
			tooth.quaternion = Quaternion(Vector3.UP,outward)
	for i in range(6):
		var wrap := CylinderMesh.new()
		wrap.top_radius = .05
		wrap.bottom_radius = .05
		wrap.height = .025
		wrap.radial_segments = 9
		_mesh(root,wrap,wood,Vector3(0,-.15+i*.075,0))
	trail_tip = Marker3D.new()
	trail_tip.position = Vector3(0,1.3,0)
	root.add_child(trail_tip)
	return root

func _apply_painted_materials() -> void:
	for mesh in meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			var source = mesh.get_active_material(surface)
			if not source is StandardMaterial3D: continue
			var outline := ShaderMaterial.new()
			outline.shader = load("res://shaders/character_ink.gdshader")
			outline.set_shader_parameter("outline_pixels",0.9 if is_enemy else 0.8)
			var paint := ShaderMaterial.new()
			paint.shader = load("res://shaders/character_painted.gdshader")
			paint.set_shader_parameter("use_texture",source.albedo_texture!=null)
			paint.set_shader_parameter("base_tint",source.albedo_color)
			paint.set_shader_parameter("readability_light",.25 if is_enemy else .38)
			paint.set_shader_parameter("paint_exposure",1.05 if is_enemy else 1.18)
			if source.albedo_texture:paint.set_shader_parameter("albedo_texture",source.albedo_texture)
			paint.next_pass = outline
			mesh.set_surface_override_material(surface,paint)

func play(name: String, speed := 1.0, blend := 0.06) -> void:
	if not anim or not animation_names.has(name):
		if name not in missing_clips:
			missing_clips.append(name)
			push_warning("Demo01 animation missing: " + name)
		return
	# Short transitional clips need their full follow-through within the logic state.
	var duration: float = anim.get_animation(animation_names[name]).length
	var playback := speed
	if name == "dash": playback = duration / Rules.DASH_DURATION
	if name == "hurt": playback = duration / (0.26 if is_enemy else 0.23)
	entry_pose.clear()
	entry_blend_seconds = 0.0
	if _uses_phase_clock(name):
		# A paused AnimationPlayer cannot advance its crossfade. Its outgoing pose
		# would mask the entire attack, including the damage frame. Blend the local
		# skeleton pose using the same explicit clock as the combat state instead.
		entry_blend_seconds = minf(blend, duration * 0.2)
		if Rules.ACTIONS.has(name):
			entry_blend_seconds = minf(entry_blend_seconds, float(Rules.ACTIONS[name].windup) * 0.65)
		if skeleton and entry_blend_seconds > 0:
			for i in range(skeleton.get_bone_count()):
				entry_pose.append(skeleton.get_bone_pose(i))
		anim.play(animation_names[name], 0.0, playback)
		anim.pause()
	else:
		anim.play(animation_names[name],blend,playback)
	clip = name

func _uses_phase_clock(name: String) -> bool:
	return Rules.ACTIONS.has(name) or name in ["club_attack", "run_start", "run_stop", "turn_left", "turn_right"]

func seek_action(name: String, seconds: float) -> void:
	if not anim or not animation_names.has(name): return
	if clip != name:
		play(name, 1.0, 0.025)
	anim.pause()
	var length: float = anim.get_animation(animation_names[name]).length
	var clock := seconds
	var authored: Dictionary = phase_map.get(name,{}) if phase_map is Dictionary else {}
	if Rules.ACTIONS.has(name):
		var d: Dictionary = Rules.ACTIONS[name]
		var total := Rules.duration(name)
		var contact := float(authored.get("contact_seconds",length*0.28))
		var active_end := float(authored.get("active_end_seconds",length*0.40))
		clock = _map_phase(seconds,float(d.windup),float(d.windup+d.active),total,contact,active_end,length)
	elif name == "club_attack":
		clock = _map_phase(seconds,0.62,0.82,1.22,float(authored.get("contact_seconds",length*0.52)),float(authored.get("active_end_seconds",length*0.68)),length)
	anim.seek(clampf(clock,0,length),true)
	if skeleton and not entry_pose.is_empty() and seconds < entry_blend_seconds:
		var weight := smoothstep(0.0, entry_blend_seconds, maxf(seconds, 0.0))
		for i in range(skeleton.get_bone_count()):
			var target := skeleton.get_bone_pose(i)
			var source := entry_pose[i]
			skeleton.set_bone_pose_position(i, source.origin.lerp(target.origin, weight))
			skeleton.set_bone_pose_rotation(i, source.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), weight))
			skeleton.set_bone_pose_scale(i, source.basis.get_scale().lerp(target.basis.get_scale(), weight))

func _map_phase(t: float, windup: float, active_end: float, duration: float, contact: float, finish: float, length: float) -> float:
	if t < windup: return lerpf(0,contact,clampf(t/maxf(windup,0.001),0,1))
	if t < active_end: return lerpf(contact,finish,clampf((t-windup)/maxf(active_end-windup,0.001),0,1))
	return lerpf(finish,length,clampf((t-active_end)/maxf(duration-active_end,0.001),0,1))

func flash(amount: float, _armor := false) -> void:
	if DisplayServer.get_name() == "headless": return
	if not flash_material: return
	flash_material.albedo_color = Color(1.0,0.24,0.055,0.9) if is_enemy else Color(1.0,0.82,0.55,0.85)
	for mesh in meshes: mesh.material_overlay = flash_material if amount > 0 else null
