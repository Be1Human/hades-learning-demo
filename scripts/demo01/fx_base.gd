extends Node3D
## Pure presentation; the owner controls time and damage independently.

const BasicRules = preload("res://scripts/demo01/rules.gd")
const MAX_DECORATIVE := 384
const MAX_CACHE := 96
const SlashMesh = preload("res://scripts/demo01/slash_mesh.gd")
const SlashShader = preload("res://shaders/demo01/sword_slash.gdshader")
const ShapeShader = preload("res://shaders/demo01/fx_shapes.gdshader")
const GOLD := Color("ffd28a")
const WHITE := Color("fff4d5")
const CYAN := Color("70e6ed")
const ARMOR := Color("83cfff")
const DANGER := Color("ff443e")
const PURPLE := Color("df69f5")
var effects: Array[Dictionary] = []
var mesh_cache: Dictionary = {}
var spark_mesh: SphereMesh
var shard_mesh: PrismMesh
var peak_count := 0
var dropped_decorative := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	spark_mesh = SphereMesh.new()
	spark_mesh.radius = 0.035
	spark_mesh.height = 0.07
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 2
	shard_mesh = PrismMesh.new()
	shard_mesh.size = Vector3(0.14,0.30,0.065)

func glow(color: Color, additive := true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	return mat

func _spawn(mesh: Mesh, color: Color, pos: Vector3, life: float, expansion := 0.0, vel := Vector3.ZERO, critical := false) -> MeshInstance3D:
	var decorative := 0
	for effect in effects:
		if not effect.critical: decorative += 1
	if not critical and decorative >= MAX_DECORATIVE:
		for i in range(effects.size()):
			if not effects[i].critical:
				effects[i].node.visible = false
				effects[i].node.queue_free()
				effects.remove_at(i)
				dropped_decorative += 1
				break
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = glow(color)
	add_child(node)
	node.global_position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effects.append({"node":node,"life":maxf(life,0.001),"total":maxf(life,0.001),"expansion":expansion,"velocity":vel,"color":color,"gravity":0.0,"critical":critical,"mode":"fade"})
	peak_count = maxi(peak_count,effects.size())
	return node

func clear() -> void:
	for effect in effects:
		if is_instance_valid(effect.node):
			effect.node.visible = false
			effect.node.queue_free()
	effects.clear()

func cancel(handle: Variant) -> void:
	# A stored handle may already have expired; typed Node3D arguments reject freed objects before entry.
	if not is_instance_valid(handle): return
	for i in range(effects.size()-1,-1,-1):
		if effects[i].node == handle or handle.is_ancestor_of(effects[i].node): effects.remove_at(i)
	handle.visible = false
	handle.queue_free()

func _cached(key: String, mesh: Mesh) -> Mesh:
	if mesh_cache.size() >= MAX_CACHE: mesh_cache.erase(mesh_cache.keys()[0])
	mesh_cache[key] = mesh
	return mesh

func _ribbon(radius: float, width: float, angle: float, tapered := true) -> ArrayMesh:
	var key := "arc:%.3f:%.3f:%.3f:%s" % [radius,width,angle,tapered]
	if mesh_cache.has(key): return mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(48):
		var points: Array[Vector3] = []
		var colors: Array[Color] = []
		for corner in [Vector2(i,0),Vector2(i,1),Vector2(i+1,1),Vector2(i+1,0)]:
			var t: float = corner.x/48.0
			var a := lerpf(-angle*0.5,angle*0.5,t)
			var w := width*pow(maxf(sin(PI*t),0.0),0.6) if tapered else width
			var r: float = radius-w*(1.0-corner.y)
			points.append(Vector3(sin(a)*r,0,cos(a)*r))
			colors.append(Color(1,1,1,0.12 if corner.y == 0 else 1.0))
		for idx in [0,1,2,0,2,3]:
			st.set_color(colors[idx])
			st.add_vertex(points[idx])
	st.generate_normals()
	return _cached(key,st.commit()) as ArrayMesh

func ring(radius: float, thickness: float) -> ArrayMesh:
	return _ribbon(radius,thickness,TAU,false)

func _line(start: Vector3, end: Vector3, width: float, color: Color, life: float) -> MeshInstance3D:
	var length := maxf(start.distance_to(end),0.001)
	var key := "line:%.3f:%.3f" % [width,length]
	var mesh: CylinderMesh
	if mesh_cache.has(key): mesh = mesh_cache[key]
	else:
		mesh = CylinderMesh.new()
		mesh.top_radius = width*0.12
		mesh.bottom_radius = width
		mesh.height = length
		mesh.radial_segments = 5
		_cached(key,mesh)
	var node := _spawn(mesh,color,(start+end)*0.5,life)
	if start.distance_squared_to(end) > 0.000001: node.quaternion = Quaternion(Vector3.UP,(end-start).normalized())
	return node

func _expand(pos: Vector3, radius: float, color: Color, life: float, start := 0.18) -> MeshInstance3D:
	var node := _spawn(ring(radius,radius*0.065),color,pos+Vector3.UP*0.06,life)
	node.scale = Vector3(start,1,start)
	effects[-1].mode = "expand"
	effects[-1].start_scale = node.scale
	effects[-1].end_scale = Vector3.ONE
	return node

func stamp(pos: Vector3, size: Vector2, color: Color, life: float, shape: int, ground := false, critical := false) -> MeshInstance3D:
	var key := "stamp:%.3f:%.3f" % [size.x,size.y]
	if not mesh_cache.has(key):
		var quad := QuadMesh.new()
		quad.size = size
		_cached(key,quad)
	var node := _spawn(mesh_cache[key],color,pos,life,0,Vector3.ZERO,critical)
	var material := ShaderMaterial.new()
	material.shader = ShapeShader
	material.set_shader_parameter("shape",shape)
	material.set_shader_parameter("duration",life)
	material.set_shader_parameter("tint",color)
	material.set_shader_parameter("face_camera",not ground)
	node.material_override = material
	if ground: node.rotation.x = -PI/2.0
	effects[-1].mode = "stamp"
	return node

func attack(pos: Vector3, direction: Vector3, action: String) -> void:
	if not BasicRules.ACTIONS.has(action): return
	var d: Dictionary = BasicRules.ACTIONS[action]
	var forward := direction.normalized()
	if forward.is_zero_approx(): forward = Vector3.FORWARD
	var yaw := atan2(forward.x,forward.z)
	if action in ["slash_1","slash_2"]:
		painted_slash(pos,forward,action == "slash_2")
	elif action == "nova":
		_expand(pos,float(d.reach),GOLD,0.40)
		_expand(pos+Vector3.UP*0.03,float(d.reach),WHITE,0.22,0.55)
		_spawn(ring(float(d.reach),0.045),Color(1,0.40,0.16,0.7),pos+Vector3.UP*0.04,0.32)
		for i in range(12):
			var ray := Vector3(sin(i*TAU/12),0,cos(i*TAU/12))
			_line(pos+ray*0.5+Vector3.UP*0.08,pos+ray*float(d.reach)+Vector3.UP*0.08,0.045,GOLD,0.24)
		burst(pos+Vector3.UP*0.1,Vector3.UP,28,GOLD,5.0)
		stamp(pos+Vector3.UP*0.075,Vector2.ONE*float(d.reach)*2.0,GOLD,0.36,1,true)
		stamp(pos+Vector3.UP*0.55,Vector2(2.5,3.0),WHITE,0.16,0)
	elif action in ["thrust","dash_strike"]:
		var origin := pos+Vector3.UP*0.85
		_line(origin,origin+forward*float(d.reach),0.22,WHITE,0.14)
		var side := Vector3(forward.z,0,-forward.x)
		for sign_value in [-1,1]:
			_line(origin+side*0.18*sign_value,origin+forward*float(d.reach)*0.92+side*0.06*sign_value,0.06,GOLD,0.21)
		stamp(origin+forward*float(d.reach)*0.93,Vector2(1.2,1.2),WHITE,0.11,0)
		if action == "dash_strike": _line(origin-forward*1.2,origin,0.12,CYAN,0.18)
	else:
		var sweep_sign := -1.0 if action == "slash_2" else 1.0
		for layer in [[0.42,GOLD,0.18,0.0],[0.075,WHITE,0.11,0.025],[0.30,Color(0.9,0.16,0.045,0.65),0.25,-0.12]]:
			var slash := _spawn(_ribbon(float(d.reach)+float(layer[3]),float(layer[0]),deg_to_rad(float(d.arc))),layer[1],pos+Vector3.UP*0.85,float(layer[2]))
			slash.rotation = Vector3(0,yaw,sweep_sign*0.045)
			effects[-1].spin = sweep_sign*1.8

func painted_slash(pos: Vector3, direction: Vector3, reverse := false) -> void:
	var key := "painted_slash_2" if reverse else "painted_slash_1"
	if not mesh_cache.has(key): _cached(key,SlashMesh.build(2.12 if reverse else 2.0))
	var node := _spawn(mesh_cache[key],WHITE,pos+direction*0.20+Vector3.UP*0.70,0.23)
	node.rotation.y = atan2(direction.x,direction.z)
	if reverse: node.scale.x = -1.0
	var mat := ShaderMaterial.new()
	mat.shader = SlashShader
	node.material_override = mat
	effects[-1].mode = "painted_slash"
	# Tangential chips accent the finishing side, never a radial explosion on a miss.
	var yaw := atan2(direction.x,direction.z)
	var tangent := Vector3(0.18,-0.16,0.90).normalized().rotated(Vector3.UP,yaw)
	for i in range(5):
		var p := pos+Vector3(-1.425 if reverse else 1.425,1.0+i*0.025,0.69).rotated(Vector3.UP,yaw)
		var chip := _spawn(shard_mesh,Color("ffbd65") if i%2 == 0 else Color("e94925"),p,0.15+i*0.024,0,tangent*(1.6+i*0.35)+Vector3.UP*0.3)
		chip.scale = Vector3(0.25,0.8+i*0.13,0.35)
		chip.quaternion = Quaternion(Vector3.UP,tangent)
		effects[-1].gravity = 3.0
		effects[-1].delay = 0.04
		chip.visible = false

func blade_echo(visual: ActorVisual) -> void:
	if not is_instance_valid(visual.weapon): return
	var attachment: BoneAttachment3D = visual.weapon.get_parent()
	var hand := visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(attachment.bone_idx)*visual.weapon.transform
	var hilt := hand*Vector3(0,0.40,0)
	var tip := hand*Vector3(0,1.55,0)
	_line(hilt,tip,0.028,Color(1.0,0.88,0.56,0.65),0.065)

func burst(pos: Vector3, direction: Vector3, count: int, color: Color, speed := 4.0) -> void:
	for i in range(mini(count,MAX_DECORATIVE)):
		var velocity := (direction*rng.randf_range(0.3,0.8)+Vector3(rng.randf_range(-1,1),rng.randf_range(0.2,1.2),rng.randf_range(-1,1))).normalized()*rng.randf_range(speed*0.35,speed)
		var p := _spawn(spark_mesh,color,pos,rng.randf_range(0.19,0.46),0,velocity)
		p.scale = Vector3(0.65,rng.randf_range(1.8,4.5),0.65)
		p.quaternion = Quaternion(Vector3.UP,velocity.normalized())
		effects[-1].gravity = 7.0

func impact(pos: Vector3, direction: Vector3, heavy: bool, armor: bool, broken: bool) -> void:
	var color := ARMOR if armor else GOLD
	stamp(pos+Vector3.UP,Vector2.ONE*(2.2 if heavy else 1.3),color,0.15 if heavy else 0.10,0)
	burst(pos+Vector3.UP,direction,24 if heavy else 12,color,6.0 if heavy else 4.0)
	for angle in [0.4,1.9]:
		var ray := Vector3(cos(angle),sin(angle),0)*(0.85 if heavy else 0.5)
		_line(pos+Vector3.UP-ray,pos+Vector3.UP+ray,0.10,WHITE,0.095)
	if broken:
		_expand(pos,1.45,ARMOR,0.38)
		for i in range(12):
			var ray := Vector3(sin(i*TAU/12),rng.randf_range(0.4,1.0),cos(i*TAU/12))
			var shard := _spawn(shard_mesh,ARMOR,pos+Vector3.UP,0.55,0,ray*3.6)
			shard.rotation = ray*2.0
			effects[-1].gravity = 8.0
			effects[-1].spin = 5.0

func charge(pos: Vector3, color: Color) -> Node3D:
	var node := _spawn(ring(1.2,0.12),color,pos+Vector3.UP*0.065,float(BasicRules.ACTIONS.nova.windup),0,Vector3.ZERO,true)
	effects[-1].mode = "charge"
	return node

func dash_burst(pos: Vector3, direction: Vector3) -> void:
	burst(pos+Vector3.UP*0.15,-direction,9,Color("ed743c"),3.0)
	for i in range(4):
		var offset := Vector3(0,0.25+i*0.30,0)
		_line(pos+offset-direction*1.5,pos+offset+direction*0.3,0.025,Color("ffc087"),0.18)

func afterimage(visual: ActorVisual, color: Color) -> void:
	for source in visual.meshes:
		var mesh: Mesh = source.mesh
		if source.skin != null and source.get_node_or_null(source.skeleton) is Skeleton3D:
			mesh = source.bake_mesh_from_current_skeleton_pose()
		if mesh == null: continue
		var ghost := _spawn(mesh,color,source.global_position,0.18)
		ghost.global_transform = source.global_transform

func enemy_swing(pos: Vector3, direction: Vector3) -> void:
	var sweep := _spawn(_ribbon(2.45,0.28,2.0*acos(0.25)),DANGER,pos+Vector3.UP*0.65,0.21)
	sweep.rotation.y = atan2(direction.x,direction.z)
	burst(pos+direction*1.6+Vector3.UP*0.5,direction,8,DANGER,2.5)

func warning(pos: Vector3, radius: float, life: float, direction := Vector3.FORWARD, arc := TAU, follow: Node3D = null) -> Node3D:
	var node := _spawn(_ribbon(radius,0.075,arc,false),DANGER,pos+Vector3.UP*0.055,life,0,Vector3.ZERO,true)
	node.rotation.y = atan2(direction.x,direction.z)
	effects[-1].mode = "warning"
	if follow != null: effects[-1].follow = weakref(follow)
	var fill := MeshInstance3D.new()
	fill.mesh = _ribbon(radius,radius,arc,false)
	fill.material_override = glow(Color(1,0.06,0.025,0.12))
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(fill)
	var progress := MeshInstance3D.new()
	progress.mesh = _ribbon(radius,0.11,arc,false)
	progress.material_override = glow(Color(1,0.38,0.14,0.7))
	progress.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	progress.scale = Vector3(0.05,1,0.05)
	node.add_child(progress)
	return node

func hurt(pos: Vector3, lethal := false) -> void:
	burst(pos+Vector3.UP,Vector3.UP,24 if lethal else 14,Color("ed544b"),3.0)
	_expand(pos,1.6 if lethal else 0.8,DANGER,0.4)
	if lethal: death(pos)

func death(pos: Vector3) -> void:
	for i in range(5):
		stamp(pos+Vector3(rng.randf_range(-0.45,0.45),0.65+i*0.25,rng.randf_range(-0.3,0.3)),Vector2(1.3,1.7),Color("21152b"),0.42+i*0.065,2)
		effects[-1].velocity = Vector3(0,0.7+i*0.2,0)
	burst(pos+Vector3.UP*0.7,Vector3.UP,12,Color("cfa576"),2.8)

## Future gameplay calls these at authoritative events; no collision simulation.
func tick(delta: float, combat_frozen := false) -> void:
	if delta <= 0 or combat_frozen: return
	var trails: Array[Dictionary] = []
	var arrivals: Array[Vector3] = []
	for i in range(effects.size()-1,-1,-1):
		var effect: Dictionary = effects[i]
		if not is_instance_valid(effect.node) or effect.node.is_queued_for_deletion():
			effects.remove_at(i)
			continue
		var node: MeshInstance3D = effect.node
		if effect.has("follow"):
			var target = effect.follow.get_ref()
			if not is_instance_valid(target) or target.is_queued_for_deletion():
				node.queue_free()
				effects.remove_at(i)
				continue
			node.global_position = target.global_position+effect.get("follow_offset",Vector3.UP*0.055)
		if combat_frozen and (effect.critical or effect.mode == "travel"): continue
		if float(effect.get("delay",0.0)) > 0:
			effect.delay -= delta
			if effect.delay > 0: continue
			node.visible = true
		effect.life -= delta
		if effect.life <= 0 and effect.get("loop",false):
			effect.life = float(effect.total)+fmod(float(effect.life),float(effect.total))
			node.position = effect.loop_position
		if effect.life <= 0:
			if effect.mode == "travel":
				node.global_position = effect.end
				if effect.get("arrival","") == "pickup": arrivals.append(effect.end)
			node.queue_free()
			effects.remove_at(i)
			continue
		var progress := 1.0-float(effect.life)/float(effect.total)
		if effect.mode == "painted_slash":
			node.material_override.set_shader_parameter("age",float(effect.total)-float(effect.life))
			continue
		node.position += effect.velocity*delta
		effect.velocity.y -= float(effect.gravity)*delta
		if effect.expansion != 0: node.scale = (node.scale+Vector3.ONE*float(effect.expansion)*delta).max(Vector3.ONE*0.001)
		if effect.has("spin"): node.rotation.y += float(effect.spin)*delta
		if effect.mode == "stamp":
			node.material_override.set_shader_parameter("age",float(effect.total)-float(effect.life))
			continue
		var c: Color = effect.color
		c.a *= pow(1.0-progress,0.75)
		match effect.mode:
			"expand": node.scale = effect.start_scale.lerp(effect.end_scale,1.0-pow(1.0-progress,3))
			"warning":
				c.a = 0.65+progress*0.35
				node.get_child(1).scale = Vector3(maxf(progress,0.05),1,maxf(progress,0.05))
			"charge":
				node.scale = Vector3.ONE*lerpf(1.0,0.12,progress)
				c.a = 0.4+progress*0.6
			"travel":
				node.global_position = effect.start.lerp(effect.end,progress)
				c.a = 1.0
				effect.trail_clock += delta
				if effect.trail_clock >= 0.035:
					effect.trail_clock = 0.0
					trails.append({"pos":node.global_position,"color":effect.color})
			"drop":
				if node.position.y < float(effect.floor_y):
					node.position.y = effect.floor_y
					effect.velocity = Vector3.ZERO
					effect.gravity = 0.0
		node.material_override.albedo_color = c
	for trail in trails:
		var mote := _spawn(spark_mesh,trail.color,trail.pos,0.18)
		mote.scale = Vector3.ONE*1.8
	for pos in arrivals:
		_expand(pos-Vector3.UP*pos.y,0.55,Color("ff7085"),0.35)
		burst(pos,Vector3.UP,8,Color("ff7085"),1.5)
