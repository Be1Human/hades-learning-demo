class_name ActorVisual
extends Node3D

var skeleton: Skeleton3D
var anim: AnimationPlayer
var meshes: Array[MeshInstance3D] = []
var flash_material: StandardMaterial3D
var weapon: Node3D
var model: Node3D
var trail_tip: Node3D
var clip := ""
var animation_names: Dictionary = {}
var is_enemy := false

func configure(path: String, enemy := false) -> void:
	is_enemy = enemy
	model = load(path).instantiate()
	add_child(model)
	_collect(model)
	_apply_painted_materials()
	flash_material = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.92, 0.66, 0.86)
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if anim:
		for name in anim.get_animation_list():
			var short_name: String = name.get_slice("/", name.get_slice_count("/") - 1)
			animation_names[short_name] = name
	if skeleton:
		var hand := -1
		for i in range(skeleton.get_bone_count()):
			var name := skeleton.get_bone_name(i).to_lower().replace("_", "")
			if name.ends_with("righthand") or name == "handr":
				hand = i
				break
		if hand >= 0:
			var attachment := BoneAttachment3D.new()
			attachment.bone_idx = hand
			skeleton.add_child(attachment)
			weapon = _make_weapon(enemy)
			attachment.add_child(weapon)
	play("idle")

func _collect(node: Node) -> void:
	if node is Skeleton3D:
		skeleton = node
	if node is AnimationPlayer:
		anim = node
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect(child)

func _apply_painted_materials() -> void:
	var outline := ShaderMaterial.new()
	outline.shader = load("res://shaders/ink_outline.gdshader")
	outline.set_shader_parameter("thickness", 0.004)
	for mesh in meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			var source = mesh.get_active_material(surface)
			if source is StandardMaterial3D:
				var painted: StandardMaterial3D = source.duplicate()
				painted.metallic = 0.0
				painted.roughness = 0.92
				painted.normal_enabled = false
				painted.next_pass = outline
				mesh.set_surface_override_material(surface, painted)

func play(name: String, speed := 1.0, blend := 0.06) -> void:
	if not anim:
		return
	if animation_names.has(name):
		anim.play(animation_names[name], blend, speed)
		clip = name

func set_motion(name: String, speed := 1.0) -> void:
	if clip != name:
		play(name, speed, 0.10)

func seek_action(name: String, seconds: float) -> void:
	if not anim or not animation_names.has(name):
		return
	if clip != name:
		anim.play(animation_names[name], 0.025)
		clip = name
	anim.pause()
	anim.seek(seconds, true)

func flash(amount: float, armor := false) -> void:
	flash_material.albedo_color = Color(0.35, 0.72, 1.0, 0.68) if armor else Color(1.0, 0.91, 0.64, 0.88)
	for mesh in meshes:
		mesh.material_overlay = flash_material if amount > 0 else null

func _material(color: Color, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.45
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scale_value := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.scale = scale_value
	parent.add_child(node)
	return node

func _make_weapon(enemy: bool) -> Node3D:
	var root := Node3D.new()
	# Authored rig's right hand points along local +Y. The grip passes through the palm.
	root.rotation_degrees = Vector3.ZERO
	var gold := _material(Color("9f793b"), 0.6)
	var dark := _material(Color("281a22"))
	var blade := _material(Color("e8e5c9"), 0.72, 0.1)
	var red := _material(Color("c9382b"), 0.35, 0.2)
	var grip := CylinderMesh.new()
	grip.top_radius = 0.055 if not enemy else 0.11
	grip.bottom_radius = grip.top_radius
	grip.height = 0.36 if not enemy else 1.0
	_mesh(root, grip, dark)
	if enemy:
		root.scale = Vector3.ONE * 0.78
		var club := CylinderMesh.new()
		club.top_radius = 0.25
		club.bottom_radius = 0.17
		club.height = 0.8
		club.radial_segments = 7
		_mesh(root, club, _material(Color("543d37")), Vector3(0, 0.65, 0))
		for y in [0.36, 0.82]:
			var band := CylinderMesh.new()
			band.top_radius = 0.255
			band.bottom_radius = 0.255
			band.height = 0.09
			band.radial_segments = 7
			_mesh(root, band, gold, Vector3(0, y, 0))
	else:
		var guard := BoxMesh.new()
		guard.size = Vector3(0.46, 0.09, 0.14)
		_mesh(root, guard, gold, Vector3(0, 0.22, 0))
		# Forged diamond blade, a real closed mesh rather than a flat slash graphic.
		var vertices := PackedVector3Array([Vector3(0,0.27,0.08),Vector3(-0.13,0.27,0),Vector3(0.13,0.27,0),Vector3(0,0.27,-0.08),Vector3(0,1.55,0)])
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in [[0,1,4],[2,0,4],[3,2,4],[1,3,4],[0,2,1],[1,2,3]]:
			for idx in face:
				st.add_vertex(vertices[idx])
		st.generate_normals()
		_mesh(root, st.commit(), blade)
		var core := BoxMesh.new()
		core.size = Vector3(0.055, 0.94, 0.035)
		_mesh(root, core, red, Vector3(0, 0.78, 0.081))
		var pommel := SphereMesh.new()
		pommel.radius = 0.09
		pommel.height = 0.18
		_mesh(root, pommel, gold, Vector3(0,-0.23,0))
	trail_tip = Node3D.new()
	trail_tip.position = Vector3(0, 1.55 if not enemy else 1.05, 0)
	root.add_child(trail_tip)
	return root
