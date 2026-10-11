class_name CombatFX
extends Node3D
## Pure presentation; the owner controls time and damage independently.

const MAX_DECORATIVE := 384
const MAX_CACHE := 96
const SlashMesh = preload("res://scripts/sword_slash_mesh.gd")
const SlashShader = preload("res://shaders/sword_slash.gdshader")
const ShapeShader = preload("res://shaders/fx_shapes.gdshader")
const ReviveFlowShader = preload("res://shaders/revive_flow.gdshader")
const ReviveScreenShader = preload("res://shaders/revive_screen.gdshader")
const RibbonShader = preload("res://shaders/fx_ribbon.gdshader")
const RibbonMesh = preload("res://scripts/fx_ribbon_mesh.gd")
const GhostShader = preload("res://shaders/fx_ghost.gdshader")
const WarningShader = preload("res://shaders/fx_warning.gdshader")
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
const MAX_FLASH_LIGHTS := 8
var flash_lights: Array[Dictionary] = []
const MAX_SOURCE_LIGHTS := 12
var source_lights: Array[Dictionary] = []
var revive_handle: WeakRef

func _source_light(source: Node3D, color: Color, energy: float, radius: float, offset:=Vector3.ZERO) -> void:
	# A mesh's emission does not light other surfaces. Pair luminous bodies with
	# bounded real lamps and keep their position/lifetime tied to the effect owner.
	var owner_effect: Dictionary={}
	for effect in effects:
		if effect.node==source:owner_effect=effect;break
	if owner_effect.is_empty():return
	if source_lights.size()>=MAX_SOURCE_LIGHTS:
		var oldest: Dictionary=source_lights.pop_front()
		oldest.node.visible=false
		oldest.node.queue_free()
	var light:=OmniLight3D.new()
	light.name="EmissiveSourceLight"
	light.light_color=color
	light.light_energy=energy
	light.omni_range=radius
	light.omni_attenuation=2.0
	light.shadow_enabled=false
	add_child(light)
	light.global_position=source.global_position+offset
	light.visible=source.is_visible_in_tree()
	source_lights.append({"node":light,"source":weakref(source),"effect":owner_effect,"energy":energy,"offset":offset})

func _sync_source_lights() -> void:
	for i in range(source_lights.size()-1,-1,-1):
		var slot: Dictionary=source_lights[i]
		var source=slot.source.get_ref()
		if not is_instance_valid(source) or source.is_queued_for_deletion():
			slot.node.visible=false
			slot.node.queue_free()
			source_lights.remove_at(i)
			continue
		slot.node.global_position=source.global_position+slot.offset
		slot.node.visible=source.is_visible_in_tree()
		var effect: Dictionary=slot.effect
		var fade:=1.0 if effect.get("loop",false) else clampf(float(effect.life)/float(effect.total),0.0,1.0)
		slot.node.light_energy=slot.energy*sqrt(fade)
		if source.material_override is StandardMaterial3D:
			slot.node.light_color=source.material_override.albedo_color

func light_flash(pos: Vector3, color: Color, energy: float, radius: float, life: float) -> void:
	# Bounded, reused lamps are separate from mesh effects and damage/telegraph budgets.
	var slot: Dictionary = {}
	for candidate in flash_lights:
		if candidate.life <= 0:
			slot=candidate
			break
	if slot.is_empty():
		if flash_lights.size() < MAX_FLASH_LIGHTS:
			var light:=OmniLight3D.new()
			light.name="CombatLight"
			# Short flashes spread reflected color without stamping hard moving shadows.
			light.shadow_enabled=false
			light.shadow_bias=.025
			light.shadow_normal_bias=.4
			light.light_size=.7
			light.omni_attenuation=1.5
			add_child(light)
			slot={"node":light,"life":0.0,"total":1.0,"energy":0.0}
			flash_lights.append(slot)
		else:
			slot=flash_lights[0]
			for candidate in flash_lights:
				if candidate.life/candidate.total < slot.life/slot.total:slot=candidate
	var lamp: OmniLight3D=slot.node
	lamp.global_position=pos+Vector3.UP*.9
	lamp.light_color=color
	lamp.omni_range=radius
	lamp.light_energy=energy
	lamp.visible=true
	slot.life=maxf(life,.001)
	slot.total=slot.life
	slot.energy=energy

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
				cancel(effects[i].node)
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
	for slot in source_lights:
		if is_instance_valid(slot.node):
			slot.node.visible=false
			slot.node.queue_free()
	source_lights.clear()
	for slot in flash_lights:
		if is_instance_valid(slot.node):
			slot.node.visible=false
			slot.node.queue_free()
	flash_lights.clear()
	for effect in effects:
		if is_instance_valid(effect.node):
			effect.node.visible = false
			effect.node.queue_free()
	effects.clear()

func cancel(handle: Variant) -> void:
	# A stored handle may already have expired; typed Node3D arguments reject freed objects before entry.
	if not is_instance_valid(handle): return
	for i in range(source_lights.size()-1,-1,-1):
		var owner=source_lights[i].source.get_ref()
		if not is_instance_valid(owner) or owner==handle or handle.is_ancestor_of(owner):
			source_lights[i].node.visible=false
			source_lights[i].node.queue_free()
			source_lights.remove_at(i)
	for i in range(effects.size()-1,-1,-1):
		if not is_instance_valid(effects[i].node) or effects[i].node == handle or handle.is_ancestor_of(effects[i].node): effects.remove_at(i)
	handle.visible = false
	handle.queue_free()

func _cached(key: String, mesh: Mesh) -> Mesh:
	if mesh_cache.size() >= MAX_CACHE: mesh_cache.erase(mesh_cache.keys()[0])
	mesh_cache[key] = mesh
	return mesh

func _delay_last(delay: float) -> void:
	if delay <= 0: return
	effects[-1].delay = delay
	effects[-1].node.visible = false

func _polish_warning(node: MeshInstance3D, reach: float, lane := false) -> void:
	var material := ShaderMaterial.new()
	material.shader = WarningShader
	material.set_shader_parameter("reach",reach)
	material.set_shader_parameter("lane",lane)
	node.get_child(0).material_override = material

func _path(points: Array[Vector3], width: float, color: Color, life: float, style := 0, delay := 0.0, vertical := false) -> MeshInstance3D:
	if points.size()==3 and style!=2:
		var curve: Array[Vector3]=[]
		for i in range(25):
			var u:=i/24.0
			curve.append(points[0]*(1.0-u)*(1.0-u)+points[1]*2.0*u*(1.0-u)+points[2]*u*u)
		points=curve
	var normal := Vector3.UP
	var camera := get_viewport().get_camera_3d()
	if vertical: normal = camera.global_basis.z if camera else Vector3.BACK
	var node := _spawn(RibbonMesh.build(points,width,normal),color,Vector3.ZERO,life)
	var mat := ShaderMaterial.new()
	mat.shader = RibbonShader
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("duration",life)
	mat.set_shader_parameter("style",style)
	mat.set_shader_parameter("seed",rng.randf()*20.0)
	node.material_override = mat
	effects[-1].mode = "stamp"
	_delay_last(delay)
	return node

func _arc(pos: Vector3, direction: Vector3, radius: float, angle: float, width: float, color: Color, life: float, style := 0, delay := 0.0) -> MeshInstance3D:
	var points: Array[Vector3] = []
	for i in range(41):
		var u := i/40.0
		var wave:=sin(u*TAU*3.0+0.7)*0.045+sin(u*TAU*7.0)*0.015 if style==1 else 0.0
		points.append(pos+direction.rotated(Vector3.UP,(u-0.5)*angle)*radius*(1.0+wave)+Vector3.UP*(sin(u*PI)*0.12+wave*1.8))
	return _path(points,width,color,life,style,delay)

func _wisps(pos: Vector3, direction: Vector3, color: Color, count: int, spread := 1.0, life := 0.5, delay := 0.0) -> void:
	for i in range(count):
		var ray := direction.rotated(Vector3.UP,rng.randf_range(-1.1,1.1))
		var start := pos+Vector3(rng.randf_range(-0.15,0.15),rng.randf_range(-0.1,0.1),rng.randf_range(-0.15,0.15))
		var end := start+ray*rng.randf_range(0.45,spread)+Vector3.UP*rng.randf_range(0.15,0.8)
		var s := rng.randf_range(0.07,0.17)
		_flow_stamp(start,Vector2(s,s*1.6),color,life*rng.randf_range(0.65,1.0),2,delay+rng.randf_range(0,0.045))
		effects[-1].curve = [start,start+ray*spread*0.7+Vector3.UP*0.7,end]

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

func _gem_mesh() -> ArrayMesh:
	if mesh_cache.has("bloodstone-gem"): return mesh_cache["bloodstone-gem"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(4):
		var a := Vector3(cos(i*PI/2.0)*0.23,0,sin(i*PI/2.0)*0.23)
		var b := Vector3(cos((i+1)*PI/2.0)*0.23,0,sin((i+1)*PI/2.0)*0.23)
		for vertex in [Vector3(0,0.36,0),a,b,Vector3(0,-0.36,0),b,a]:
			st.set_color(Color(1,0.65,0.72) if i%2 == 0 else Color(0.48,0.22,0.38))
			st.add_vertex(vertex)
	st.generate_normals()
	return _cached("bloodstone-gem",st.commit()) as ArrayMesh

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
	# Contact flashes sit just in front of the contact surface, rather than inside the actor.
	if shape==0 and not ground:
		var camera:=get_viewport().get_camera_3d()
		if camera:node.global_position+=camera.global_basis.z*0.48
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
	if not CombatRules.ACTIONS.has(action): return
	var d: Dictionary = CombatRules.ACTIONS[action]
	var forward := direction.normalized()
	if forward.is_zero_approx(): forward = Vector3.FORWARD
	light_flash(pos+forward*0.7,GOLD,2.8,4.0,0.16)
	if action in ["slash_1","slash_2"]:
		painted_slash(pos,forward,action=="slash_2")
	elif action == "nova":
		var radius := float(d.reach)
		stamp(pos+Vector3.UP*0.5,Vector2(1.8,2.5),WHITE,0.13,0)
		stamp(pos+Vector3.UP*0.07,Vector2.ONE*radius*2.0,GOLD,0.48,1,true)
		for i in range(7):
			var ray := forward.rotated(Vector3.UP,i*TAU/7.0)
			_arc(pos+ray*0.3+Vector3.UP*0.10,ray,radius*0.68,0.8,0.20,Color("e28b42"),0.46,4,0.04+i*0.011)
			stamp(pos+ray*radius*0.58+Vector3.UP*0.15,Vector2(0.9,0.5),Color(0.42,0.31,0.19,0.35),0.52,2)
			_delay_last(0.08+i*0.012)
		burst(pos+Vector3.UP*0.15,Vector3.UP,20,GOLD,4.6)
	elif action in ["thrust","dash_strike"]:
		var origin := pos+Vector3.UP*0.85
		var reach := float(d.reach)
		var side := Vector3(forward.z,0,-forward.x)
		_path([origin-forward*0.18,origin+forward*reach*0.3+Vector3.UP*0.06,origin+forward*reach],0.48,WHITE,0.19)
		for sign_value in [-1,1]:
			_path([origin+side*sign_value*0.24,origin+forward*reach*0.45+side*sign_value*0.14,origin+forward*reach*0.95],0.17,Color("ed7943"),0.29,0,0.025)
		stamp(origin+forward*reach*0.95,Vector2.ONE*0.8,WHITE,0.10,0)
		_delay_last(0.04)
		if action=="dash_strike":
			_path([origin-forward*1.7,origin-forward*0.8+side*0.10,origin+forward*0.4],0.5,Color("b94932"),0.35,4)
		_wisps(origin+forward*reach*0.6,forward,GOLD,6,1.0,0.28,0.04)

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
		var velocity := (direction*rng.randf_range(0.7,1.5)+Vector3(rng.randf_range(-1,1),rng.randf_range(0.1,0.9),rng.randf_range(-1,1))).normalized()*rng.randf_range(speed*0.3,speed)
		var life := rng.randf_range(0.20,0.55)
		var p: MeshInstance3D
		if i%3==0:
			p = _spawn(shard_mesh,color,pos,life,0,velocity)
			p.scale = Vector3(0.30,rng.randf_range(0.7,1.7),0.25)
			p.quaternion = Quaternion(Vector3.UP,velocity.normalized())
			effects[-1].spin = rng.randf_range(-5,5)
		else:
			var size := rng.randf_range(0.05,0.12)
			p = _flow_stamp(pos,Vector2(size,size*1.8),color,life,2)
			effects[-1].velocity = velocity
		effects[-1].gravity = 5.5
		effects[-1].drag = 2.2
		_delay_last(rng.randf_range(0,0.035))

func impact(pos: Vector3, direction: Vector3, heavy: bool, armor: bool, broken: bool) -> void:
	var color := ARMOR if armor else GOLD
	var center := pos+Vector3.UP
	light_flash(pos,color,3.6 if heavy else 2.2,3.5,0.16)
	stamp(center,Vector2.ONE*(2.3 if heavy else 1.35),WHITE,0.16 if heavy else 0.105,0)
	burst(center,direction,22 if heavy else 10,color,5.5 if heavy else 3.5)
	var side := Vector3(direction.z,0,-direction.x)
	for sign_value in [-1,1]:
		_path([center-side*sign_value*0.22,center+direction*0.35+Vector3.UP*0.25,center+direction*0.8+side*sign_value*0.5],0.12,color,0.22,0,0.02,true)
	if heavy:
		stamp(center,Vector2(1.5,1.8),Color(0.24,0.13,0.07,0.65),0.44,2)
		_delay_last(0.07)
	if armor:
		_arc(center,direction,0.78,2.8,0.16,ARMOR,0.24,3,0.03)
	if broken:
		stamp(pos+Vector3.UP*0.07,Vector2.ONE*2.9,ARMOR,0.46,1,true)
		_delay_last(0.055)
		for i in range(9):
			var ray := Vector3(cos(i*TAU/9),rng.randf_range(0.3,1.1),sin(i*TAU/9))
			var shard := _spawn(shard_mesh,Color("b8ebff"),center,0.7,0,ray*2.7)
			shard.scale = Vector3(rng.randf_range(0.8,1.6),rng.randf_range(1.5,2.7),0.25)
			shard.rotation = ray*2.0
			effects[-1].gravity = 6.8
			effects[-1].spin = rng.randf_range(-7,7)
			_delay_last(0.035+i*0.007)

func backstab(pos: Vector3) -> void:
	var c := pos+Vector3.UP*2.0
	_path([c+Vector3(-0.48,-0.28,0),c+Vector3(0,0.22,0),c+Vector3(0.18,0.68,0)],0.16,Color("ff765e"),0.27,0,0.0,true)
	_path([c+Vector3(0.48,-0.28,0),c+Vector3(0,0.22,0),c+Vector3(-0.18,0.68,0)],0.12,GOLD,0.30,0,0.025,true)
	stamp(c,Vector2.ONE*0.8,WHITE,0.095,0)
	_wisps(c,Vector3.UP,Color("ff976f"),7,0.7,0.35,0.045)

func charge(pos: Vector3, color: Color) -> Node3D:
	var life := float(CombatRules.ACTIONS.nova.windup)
	var root := stamp(pos+Vector3.UP*1.35,Vector2.ONE*1.8,color,life,4,false,true)
	effects[-1].charge_root = true
	_source_light(root,color,2.2,3.5)
	for i in range(6):
		var a := i*TAU/6.0
		var start := pos+Vector3(cos(a)*1.3,0.3,sin(a)*1.3)
		var p := _flow_stamp(start,Vector2(0.13,0.23),color,life,2)
		effects[-1].curve = [start,start+Vector3(-sin(a)*0.45,0.4,cos(a)*0.45),pos+Vector3.UP*0.8]
		effects[-1].critical = true
		p.reparent(root,true)
	return root

func dash_burst(pos: Vector3, direction: Vector3) -> void:
	light_flash(pos,Color("ff7438"),1.8,2.6,0.18)
	var side := Vector3(direction.z,0,-direction.x)
	for i in range(3):
		var center := pos+Vector3.UP*(0.25+i*0.28)+side*(i-1)*0.18
		_path([center-direction*(1.9-i*0.2),center-direction*0.6+side*(i-1)*0.15,center+direction*0.35],0.3-i*0.05,Color("e99252") if i==1 else Color("ab452c"),0.28+i*0.025,0,i*0.012)
	_wisps(pos+Vector3.UP*0.3,-direction,Color("ffc27b"),9,1.6,0.4)
	dust(pos-direction*0.5)

func afterimage(visual: ActorVisual, color: Color) -> void:
	for source in visual.meshes:
		var mesh: Mesh = source.mesh
		if source.skin != null and source.get_node_or_null(source.skeleton) is Skeleton3D: mesh = source.bake_mesh_from_current_skeleton_pose()
		if mesh == null: continue
		var ghost := _spawn(mesh,color,source.global_position,0.25)
		ghost.global_transform = source.global_transform
		var mat := ShaderMaterial.new()
		mat.shader = GhostShader
		mat.set_shader_parameter("tint",Color(1.0,0.40,0.12,color.a))
		mat.set_shader_parameter("duration",0.25)
		ghost.material_override = mat
		effects[-1].mode = "stamp"

func dust(pos: Vector3) -> void:
	for i in range(5):
		var a := rng.randf()*TAU
		stamp(pos+Vector3(cos(a)*0.24,0.16,sin(a)*0.24),Vector2(rng.randf_range(0.65,0.95),0.45),Color(0.50,0.40,0.29,0.56),0.40+i*0.035,2)
		effects[-1].velocity = Vector3(cos(a)*0.55,0.12,sin(a)*0.55)
		effects[-1].drag = 2.5
		_delay_last(i*0.012)

func enemy_swing(pos: Vector3, direction: Vector3) -> void:
	_arc(pos+Vector3.UP*0.7,direction,2.45,2.0*acos(0.25),0.64,Color("ff6744"),0.27)
	_arc(pos+Vector3.UP*0.66,direction,2.2,2.0,0.26,Color("8c2028"),0.39,4,0.035)
	_wisps(pos+direction*1.6+Vector3.UP*0.6,direction,Color("ffac6e"),8,1.1,0.36,0.055)

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
	_polish_warning(node,radius)
	return node

func hurt(pos: Vector3, lethal := false) -> void:
	light_flash(pos,DANGER,2.4 if lethal else 1.5,3.0,0.14)
	stamp(pos+Vector3.UP,Vector2.ONE*(1.5 if lethal else 1.0),Color("ffc5a6"),0.095,0)
	burst(pos+Vector3.UP,Vector3.UP,18 if lethal else 8,Color("d52f42"),3.0)
	if lethal:
		stamp(pos+Vector3.UP*0.035,Vector2.ONE*3.2,Color(0.20,0.005,0.025,0.9),0.95,2,true)
		for i in range(5):
			stamp(pos+Vector3((i-2)*0.2,0.65+i*0.18,0),Vector2(1.2,1.7),Color(0.18,0.015,0.025,0.8),0.8+i*0.045,2)
			effects[-1].velocity = Vector3(0,0.45,0)
			_delay_last(0.06+i*0.025)
	else:
		_arc(pos+Vector3.UP*0.7,Vector3.BACK,0.65,2.2,0.17,Color("cd3147"),0.32,4,0.015)

func _lane_mesh(width: float, length: float, filled: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := width*0.5
	var rectangles := [Rect2(-w,0,width,length)] if filled else [Rect2(-w,0,0.055,length),Rect2(w-0.055,0,0.055,length),Rect2(-w,0,width,0.055),Rect2(-w,length-0.055,width,0.055)]
	for rect: Rect2 in rectangles:
		var corners := [Vector3(rect.position.x,0,rect.position.y),Vector3(rect.end.x,0,rect.position.y),Vector3(rect.end.x,0,rect.end.y),Vector3(rect.position.x,0,rect.end.y)]
		for idx in [0,1,2,0,2,3]: st.add_vertex(corners[idx])
	st.generate_normals()
	return st.commit()

func boss_warning(pos: Vector3, direction: Vector3, move: String, life := 0.75) -> Node3D:
	if move == "whip": return warning(pos,3.8,life)
	if move == "barrage": return warning(pos,6.0,life,direction,1.4)
	if move != "rush": return warning(pos,1.7,life)
	var node := _spawn(_lane_mesh(1.3,6,false),DANGER,pos+Vector3.UP*0.055,life,0,Vector3.ZERO,true)
	node.rotation.y = atan2(direction.x,direction.z)
	effects[-1].mode = "warning"
	for filled in [true,false]:
		var part := MeshInstance3D.new()
		part.mesh = _lane_mesh(1.3,6,filled)
		part.material_override = glow(Color(1,0.12,0.06,0.14 if filled else 0.8))
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(part)
	node.get_child(1).scale = Vector3(0.05,1,0.05)
	_polish_warning(node,6.0,true)
	return node

func death(pos: Vector3) -> void:
	stamp(pos+Vector3.UP*0.8,Vector2.ONE*1.5,Color("dfb286"),0.10,0)
	for i in range(6):
		var a := i*TAU/6.0
		stamp(pos+Vector3(cos(a)*0.25,0.6+i*0.14,sin(a)*0.25),Vector2(1.1,1.5),Color(0.11,0.055,0.15,0.85),0.60+i*0.045,2)
		effects[-1].velocity = Vector3(cos(a)*0.3,0.65,sin(a)*0.3)
		_delay_last(0.025*i)
	_wisps(pos+Vector3.UP*0.9,Vector3.UP,Color("b29669"),13,1.1,0.72,0.08)

func projectile(start: Vector3, end: Vector3, duration := 0.42, hostile := false) -> Node3D:
	var color := PURPLE if hostile else Color("ff4b69")
	var node := _spawn(spark_mesh if hostile else _gem_mesh(),color,start,duration,0,Vector3.ZERO,true)
	node.scale = Vector3.ONE*(2.8 if hostile else 0.68)
	if not hostile and not start.is_equal_approx(end): node.quaternion = Quaternion(Vector3.UP,(end-start).normalized())
	effects[-1].mode = "travel"
	effects[-1].start = start
	effects[-1].end = end
	effects[-1].trail_clock = 0.0
	effects[-1].trail_width = 0.30 if hostile else 0.16
	var corona := stamp(start,Vector2.ONE*(0.85 if hostile else 0.52),color,duration,5,false,true)
	corona.reparent(node,true)
	_source_light(node,color,2.1,3.6)
	return node

func bloodstone(pos: Vector3, phase: String, target := Vector3.ZERO, follow: Node3D = null) -> Node3D:
	if phase=="cast":
		var root := projectile(pos,target)
		stamp(pos,Vector2.ONE*0.7,Color("ff9c9f"),0.11,0)
		return root
	if phase=="pickup":
		var root := projectile(pos,target,0.40)
		for effect in effects:
			if effect.node==root:
				effect.arrival="pickup"
				effect.travel_curve=[pos,pos+Vector3.UP*1.15,target]
		return root
	var node := _spawn(_gem_mesh(),Color("ff405d"),pos,2.0,0,Vector3.ZERO,true)
	node.scale=Vector3.ONE*1.45
	effects[-1].spin=1.2
	if phase=="embedded":
		effects[-1].hover_origin=pos
		if follow!=null:
			effects[-1].follow=weakref(follow)
			effects[-1].follow_offset=pos-follow.global_position
	if phase=="drop":
		effects[-1].mode="drop"
		effects[-1].floor_y=0.18
		effects[-1].velocity=Vector3(0,1.5,0)
		effects[-1].gravity=6.5
		effects[-1].bounce_once=true
	var halo := stamp(pos,Vector2.ONE*0.85,Color(1,0.15,0.27,0.65),2.0,5,false,true)
	halo.reparent(node,true)
	_source_light(node,Color("ff405d"),1.0,2.8)
	return node

func lightning(points: Array[Vector3]) -> void:
	for i in range(points.size()-1):
		var path: Array[Vector3]=[points[i]]
		var delta := points[i+1]-points[i]
		for j in range(1,13):
			var u := j/12.0
			var jitter := Vector3(rng.randf_range(-0.24,0.24),rng.randf_range(-0.16,0.16),rng.randf_range(-0.21,0.21))*sin(u*PI)
			path.append(points[i]+delta*u+jitter)
		var arc:=_path(path,0.18,Color("7f9ff9"),0.27,2,i*0.048,true)
		_source_light(arc,Color("a7bcff"),3.2,4.0,points[i+1]-arc.global_position+Vector3.UP*.5)
		_path(path,0.045,WHITE,0.12,2,i*0.048,true)
		for branch in [3,7,9]:
			var start := path[branch]
			var end := start+Vector3(rng.randf_range(-0.7,0.7),-0.4,rng.randf_range(-0.5,0.5))
			_path([start,start.lerp(end,0.48)+Vector3(0.12,0.1,0),end],0.055,Color("a7bcff"),0.17,2,i*0.048+0.018,true)
		stamp(points[i+1],Vector2.ONE*0.8,WHITE,0.10,0)
		_delay_last(i*0.048)
		_wisps(points[i+1],Vector3.UP,Color("b5ccff"),5,0.65,0.30,i*0.048+0.02)

func boon(pos: Vector3, direction: Vector3, family: String, slot := "attack") -> void:
	var radius := 3.15 if slot=="special" else 1.5
	if family=="lightning":
		var strikes := 3 if slot=="special" else (2 if slot=="dash" else 1)
		for i in range(strikes):
			var target := pos+direction*1.5
			if slot=="special": target=pos+direction.rotated(Vector3.UP,i*TAU/3.0)*2.0
			elif slot=="dash": target=pos-direction*(i*1.15+0.25)
			var first := effects.size()
			lightning([target+Vector3.UP*3.2,target+Vector3.UP*0.12])
			for j in range(first,effects.size()):
				effects[j].delay=float(effects[j].get("delay",0.0))+i*0.075
				if effects[j].delay>0:effects[j].node.visible=false
			stamp(target+Vector3.UP*0.065,Vector2.ONE*1.25,Color("a9ceff"),0.34,1,true)
			_delay_last(i*0.075+0.04)
	elif family=="deflect":
		light_flash(pos,Color("fff0b5"),2.4,3.8,.36)
		var arc := TAU if slot=="special" else PI*0.85
		_arc(pos+Vector3.UP*0.85,direction,radius,arc,0.52,Color("fff0b5"),0.36,3)
		_arc(pos+Vector3.UP*0.88,direction,radius*0.84,arc,0.12,Color("c1a86f"),0.49,3,0.05)
		for i in range(7 if slot=="special" else 4):
			var a := (i/6.0-0.5)*arc
			var ray := direction.rotated(Vector3.UP,a)
			var feather := stamp(pos+ray*radius+Vector3.UP*(0.7+i*0.075),Vector2(0.28,0.8),Color("fff0c1"),0.45+i*0.014,7)
			effects[-1].velocity=ray*0.85+Vector3.UP*0.4
			_delay_last(0.045+i*0.012)
			feather.rotation.z=a
	else:
		var arc := TAU if slot=="special" else 2.25
		light_flash(pos,Color("42bdd3"),2.5,4.0,.48)
		for i in range(3):
			var center := pos+direction*(0.12+i*0.10)+Vector3.UP*(0.10+i*0.15)
			_arc(center,direction,radius-i*0.12,arc,0.65-i*0.12,Color("42bdd3") if i==0 else Color("a9f1e7"),0.48+i*0.08,1,i*0.028)
			if slot!="special":effects[-1].velocity=direction*1.4
		stamp(pos+Vector3.UP*0.065,Vector2.ONE*radius*2.0,Color("5edbd8"),0.62,6,true)
		_delay_last(0.045)
		for i in range(10):
			var ray := direction.rotated(Vector3.UP,rng.randf_range(-arc*0.5,arc*0.5))
			_flow_stamp(pos+ray*radius*0.65+Vector3.UP*0.25,Vector2(0.1,0.18),Color("cbfff3"),0.48,2,0.04+i*0.012)
			effects[-1].velocity=ray*1.3+Vector3.UP*rng.randf_range(0.6,1.5)
			effects[-1].gravity=4.5
	if slot=="dash":dash_burst(pos,direction)

func wall_hit(pos: Vector3, normal: Vector3) -> void:
	var center := pos+Vector3.UP*0.7
	stamp(center,Vector2(1.2,2.2),WHITE,0.115,0)
	burst(center,normal,18,GOLD,4.2)
	for i in range(4):
		stamp(center+Vector3.UP*(i-1)*0.27,Vector2(1.1,1.0),Color(0.4,0.32,0.24,0.55),0.48+i*0.055,2)
		effects[-1].velocity=normal*0.65+Vector3.UP*0.25
		_delay_last(i*0.025)
	_wisps(center,normal,Color("a8f0e2"),9,1.6,0.48,0.03)

func boss(pos: Vector3, direction: Vector3, move: String) -> void:
	if move!="barrage":light_flash(pos+direction,PURPLE,3.0,4.5,.4)
	match move:
		"whip":
			var path: Array[Vector3]=[]
			for i in range(49):
				var u:=i/48.0
				var ray:=direction.rotated(Vector3.UP,-1.9+u*5.0)
				path.append(pos+ray*(0.55+u*3.25)+Vector3.UP*(0.9+sin(u*PI)*0.45))
			_path(path,0.33,PURPLE,0.42,0)
			_path(path,0.075,Color("fff0ff"),0.23,0,0.015)
			_wisps(path[-1],direction,PURPLE,10,1.3,0.48,0.10)
		"rush":
			var side:=Vector3(direction.z,0,-direction.x)
			for i in range(3):
				var start:=pos+side*(i-1)*0.38+Vector3.UP*(0.35+i*0.22)
				_path([start,start+direction*2.5+side*(i-1)*0.75+Vector3.UP*0.2,pos+direction*6+side*(i-1)*0.12+Vector3.UP*0.6],0.68 if i==1 else 0.25,Color("633075") if i==1 else PURPLE,0.52 if i==1 else 0.38,4 if i==1 else 0,i*0.024)
			for i in range(4):
				stamp(pos+direction*i*1.4+Vector3.UP*0.35,Vector2(1.2,0.9),Color(0.20,0.05,0.27,0.6),0.56,2)
				_delay_last(i*0.04)
		"barrage":
			for i in range(7):
				var ray:=direction.rotated(Vector3.UP,(i-3)*0.19)
				var first:=effects.size()
				projectile(pos+Vector3.UP*0.8,pos+ray*6+Vector3.UP*0.8,0.85,true)
				for j in range(first,effects.size()):
					effects[j].delay=abs(i-3)*0.035
					effects[j].node.visible=effects[j].delay==0
			stamp(pos+Vector3.UP*0.8,Vector2.ONE*1.3,PURPLE,0.3,4)
		"blast":
			stamp(pos+Vector3.UP*0.07,Vector2.ONE*3.4,PURPLE,0.65,1,true)
			stamp(pos+Vector3.UP*0.75,Vector2(1.6,2.7),WHITE,0.13,0)
			for i in range(4):
				_flow_stamp(pos+Vector3((i-1.5)*0.27,1.15,0),Vector2(1.15,2.7),Color(0.7,0.18,0.85,0.72),0.7+i*0.06,0,0.045+i*0.025)
			_wisps(pos+Vector3.UP*0.5,Vector3.UP,Color("edb0ff"),17,1.6,0.7,0.05)

func witch_cast(pos: Vector3, direction: Vector3, life := 0.55) -> Node3D:
	var center:=pos+direction.normalized()*0.5+Vector3.UP*1.2
	var root:=stamp(center,Vector2.ONE*1.45,PURPLE,life,4,false,true)
	_source_light(root,PURPLE,1.8,3.5)
	for i in range(7):
		var a:=i*TAU/7.0
		var start:=center+Vector3(cos(a)*0.85,sin(a)*0.75,0)
		var mote:=_flow_stamp(start,Vector2(0.11,0.24),Color("ebaaff"),life,2)
		effects[-1].curve=[start,start+Vector3(-sin(a)*0.35,cos(a)*0.35,0),center]
		effects[-1].critical=true
		mote.reparent(root,true)
	return root

func witch_impact(pos: Vector3, direction: Vector3) -> void:
	light_flash(pos-Vector3.UP*.5,PURPLE,2.6,3.6,.22)
	stamp(pos,Vector2.ONE*1.35,Color("f9d5ff"),0.10,0)
	for i in range(3):
		stamp(pos+Vector3.UP*i*0.15,Vector2(1.2,1.4),Color(0.23,0.065,0.29,0.72),0.48+i*0.06,2)
		effects[-1].velocity=-direction*0.55+Vector3.UP*0.3
		_delay_last(0.025+i*0.02)
	_wisps(pos,-direction,PURPLE,11,1.4,0.46,0.035)

func skull_warning(pos: Vector3, direction: Vector3, life := 0.55, follow: Node3D = null) -> Node3D:
	# Narrow lane matches a committed rush direction, not the brute's sector.
	var root := _spawn(_lane_mesh(0.85,3.6,false),DANGER,pos+Vector3.UP*0.055,life,0,Vector3.ZERO,true)
	root.rotation.y = atan2(direction.x,direction.z)
	effects[-1].mode = "warning"
	if follow != null: effects[-1].follow = weakref(follow)
	for filled in [true,false]:
		var part := MeshInstance3D.new()
		part.mesh = _lane_mesh(0.85,3.6,filled)
		part.material_override = glow(Color(1,0.2,0.05,0.12 if filled else 0.75))
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(part)
	root.get_child(1).scale = Vector3(0.05,1,0.05)
	_polish_warning(root,3.6,true)
	return root

func skull_rush(pos: Vector3, direction: Vector3) -> Node3D:
	var root:=projectile(pos+Vector3.UP*0.7,pos+direction.normalized()*3.6+Vector3.UP*0.7,0.28,true)
	for effect in effects:
		if effect.node==root:effect.color=Color("ffad70")
		elif root.is_ancestor_of(effect.node):
			effect.color=Color("ffad70")
			effect.node.material_override.set_shader_parameter("tint",Color("ffad70"))
	root.material_override.albedo_color=Color("ffad70")
	_path([pos-direction*0.8+Vector3.UP*0.7,pos+direction*0.4+Vector3.UP*0.8,pos+direction*3.6+Vector3.UP*0.65],0.44,Color("cc7138"),0.38,0)
	dust(pos)
	return root

func skull_impact(pos: Vector3, direction: Vector3) -> void:
	stamp(pos+Vector3.UP*0.65,Vector2.ONE*1.4,WHITE,0.10,0)
	stamp(pos+Vector3.UP*0.07,Vector2.ONE*1.8,Color("e7b573"),0.36,6,true)
	burst(pos+Vector3.UP*0.55,-direction,12,GOLD,3.6)
	dust(pos)

func reflected_projectile(pos: Vector3, end: Vector3, duration := 0.5) -> Node3D:
	var root:=projectile(pos,end,duration,false)
	root.material_override.albedo_color=WHITE
	for effect in effects:
		if effect.node==root:effect.color=WHITE
		elif root.is_ancestor_of(effect.node):
			effect.color=WHITE
			effect.node.material_override.set_shader_parameter("tint",WHITE)
	stamp(pos,Vector2.ONE*1.1,WHITE,0.095,0)
	_arc(pos,Vector3.FORWARD,0.48,2.3,0.14,GOLD,0.24,3)
	return root

func ambient(pos: Vector3, kind: String, persistent := false) -> Node3D:
	var start_index := effects.size()
	var root: Node3D
	if kind == "brazier_fire":
		root = _flow_stamp(pos+Vector3.UP*0.72,Vector2(1.3,1.8),Color("64ef9c"),2.4,0)
		for i in range(2):
			var tongue := _flow_stamp(pos+Vector3((i*2-1)*0.22,0.58,0.05),Vector2(0.75,1.45),Color(0.12,0.75,0.40,0.65),2.4,0)
			tongue.reparent(root,true)
		if persistent:
			for i in range(start_index,effects.size()):
				effects[i].node.material_override.set_shader_parameter("continuous",true)
				effects[i].flow_time = 0.0
				effects[i].critical = true
	else:
		root = _flow_stamp(pos,Vector2.ONE,Color(0,0,0,0),2.4,2)
		for i in range(16):
			var start := pos+Vector3(rng.randf_range(-2.3,2.3),rng.randf_range(0.15,1.8),rng.randf_range(-1.6,1.6))
			var size := rng.randf_range(0.06,0.13)
			var mote := _flow_stamp(start,Vector2(size,size*1.35),Color(0.4,0.82,0.64,0.65),2.4,2)
			effects[-1].mote_origin = start-pos
			effects[-1].mote_phase = rng.randf()*TAU
			effects[-1].flow_time = 0.0
			effects[-1].critical = persistent
			mote.reparent(root,true)
	if persistent:
		for i in range(start_index,effects.size()):
			effects[i].critical = true
			effects[i].loop = true
			effects[i].loop_position = effects[i].node.position
	return root

func _flow_stamp(pos: Vector3, size: Vector2, color: Color, life: float, layer: int, delay := 0.0, ground := false) -> MeshInstance3D:
	var node := stamp(pos,size,color,life,0,ground)
	var mat := ShaderMaterial.new()
	mat.shader = ReviveFlowShader
	mat.set_shader_parameter("duration",life)
	mat.set_shader_parameter("layer",layer)
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("face_camera",not ground)
	mat.set_shader_parameter("seed",rng.randf()*20.0)
	node.material_override = mat
	if delay > 0:
		effects[-1].delay = delay
		node.visible = false
	return node

func revive(pos: Vector3) -> Node3D:
	# Distinct authored phases: compression, ignition, torn recovery veils, drifting embers.
	# Pure presentation. No health, time_scale, input or camera state is modified here.
	if revive_handle != null: cancel(revive_handle.get_ref())
	var root := _flow_stamp(pos,Vector2.ONE,Color(0,0,0,0),1.85,2)
	revive_handle = weakref(root)
	var overlay := CanvasLayer.new()
	overlay.layer = 3
	root.add_child(overlay)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = get_viewport().get_visible_rect().size
	var screen := ShaderMaterial.new()
	screen.shader = ReviveScreenShader
	rect.material = screen
	overlay.add_child(rect)
	effects[-1].screen = screen
	effects[-1].screen_rect = rect
	effects[-1].screen_origin = pos+Vector3.UP*0.8
	var camera := get_viewport().get_camera_3d()
	if camera: screen.set_shader_parameter("center",camera.unproject_position(pos+Vector3.UP*0.8)/rect.size)
	# Compression motes follow curved paths, rather than uniformly rising straight lines.
	for i in range(14):
		var a := i*TAU/14.0+rng.randf_range(-0.15,0.15)
		var start := pos+Vector3(cos(a)*1.3,rng.randf_range(0.3,1.3),sin(a)*1.3)
		var mote := _flow_stamp(start,Vector2(0.19,0.32),Color("ff8669"),0.34,2)
		effects[-1].curve = [start,start+Vector3(-sin(a)*0.6,0.4,cos(a)*0.6),pos+Vector3.UP*0.8]
		mote.reparent(root,true)
	var ignition := _flow_stamp(pos+Vector3.UP*0.9,Vector2.ONE*3.7,Color("fff1b8"),0.18,3,0.30)
	ignition.reparent(root,true)
	_source_light(ignition,Color("fff1b8"),5.0,5.5)
	var wave := _flow_stamp(pos+Vector3.UP*0.08,Vector2.ONE*6.4,Color(0.61,0.92,0.58,0.8),0.67,1,0.31,true)
	wave.reparent(root,true)
	for i in range(3):
		var offset := Vector3((i-1)*0.43,1.2+(i%2)*0.16,(i-1)*0.28)
		var veil := _flow_stamp(pos+offset,Vector2(1.7,2.9),Color(0.20,0.91,0.56,0.68),0.95+i*0.09,0,0.32+i*0.045)
		veil.reparent(root,true)
	for i in range(28):
		var a := rng.randf()*TAU
		var start := pos+Vector3(cos(a)*0.3,rng.randf_range(0.2,1.1),sin(a)*0.3)
		var end := pos+Vector3(cos(a)*rng.randf_range(1.0,2.1),rng.randf_range(1.4,3.2),sin(a)*rng.randf_range(1.0,2.1))
		var bend := start+Vector3(cos(a+1.2)*1.4,1.6,sin(a+1.2)*1.4)
		var s := rng.randf_range(0.055,0.14)
		var mote := _flow_stamp(start,Vector2(s,s*1.8),Color("c3f7ad"),rng.randf_range(0.7,1.18),2,0.33+rng.randf()*0.18)
		effects[-1].curve = [start,bend,end]
		mote.reparent(root,true)
	return root

func world_event(pos: Vector3, event: String) -> void:
	if event=="revive":
		revive(pos)
		return
	if event=="spawn":
		light_flash(pos,Color("81eeb0"),1.8,3.5,.7)
		stamp(pos+Vector3.UP*0.06,Vector2.ONE*2.8,Color("81eeb0"),0.7,1,true)
		for i in range(3):
			_flow_stamp(pos+Vector3((i-1)*0.30,1.0,0),Vector2(1.2,2.6),Color(0.2,0.85,0.5,0.62),0.85+i*0.07,0,0.07+i*0.055)
		_wisps(pos+Vector3.UP*0.2,Vector3.UP,Color("b7f7b2"),18,1.2,0.95,0.1)
	elif event=="reward":
		var gem:=_spawn(_gem_mesh(),GOLD,pos+Vector3.UP*2.45,1.6)
		gem.scale=Vector3.ONE*1.6
		effects[-1].spin=1.6
		_source_light(gem,GOLD,3.0,5.0)
		stamp(pos+Vector3.UP*2.45,Vector2.ONE*1.8,Color(1,0.8,0.38,0.6),1.35,5)
		for j in range(2):
			var points: Array[Vector3]=[]
			for i in range(25):
				var u:=i/24.0;var a:=u*TAU+j*PI
				points.append(pos+Vector3(cos(a)*(0.7-u*0.35),0.2+u*1.8,sin(a)*(0.7-u*0.35)))
			_path(points,0.13,GOLD,1.1,3,j*0.10,true)
		_wisps(pos+Vector3.UP*0.3,Vector3.UP,Color("ffeab0"),16,1.4,1.3,0.1)
	elif event=="heal":
		light_flash(pos,Color("76f3a7"),2.2,3.8,.65)
		var c:=pos+Vector3.UP*2.25
		_path([c+Vector3(-0.40,0,0),c,c+Vector3(0.40,0,0)],0.20,Color("c4ffc0"),0.48,3,0.08,true)
		_path([c-Vector3.UP*0.4,c,c+Vector3.UP*0.4],0.20,Color("c4ffc0"),0.48,3,0.08,true)
		for i in range(9):
			var a:=i*TAU/9.0;var start:=pos+Vector3(cos(a)*1.05,0.25,sin(a)*1.05)
			_flow_stamp(start,Vector2(0.13,0.25),Color("76f3a7"),0.70,2,i*0.02)
			effects[-1].curve=[start,start+Vector3(-sin(a)*0.3,0.8,cos(a)*0.3),c]
		stamp(pos+Vector3.UP*0.06,Vector2.ONE*1.9,Color(0.3,0.9,0.5,0.6),0.75,1,true)
	elif event=="exit":
		# A vertically oriented torn aperture; visually distinct from healing and respawn.
		var center:=pos+Vector3.UP*1.6
		for j in range(3):
			var points: Array[Vector3]=[]
			for i in range(49):
				var a:=i*TAU/48.0
				points.append(center+Vector3(sin(a)*(1.0+j*0.06),cos(a)*(1.5+j*0.05),0))
			var rim:=_path(points,0.22-j*0.04,Color("8fe5d5") if j==0 else Color("367e91"),1.65+j*0.07,3,j*0.05,true)
			if j==0:_source_light(rim,Color("8fe5d5"),2.8,4.5,center-rim.global_position)
		stamp(center,Vector2(1.6,2.7),Color(0.025,0.06,0.07,0.8),1.65,2)
		_wisps(center,Vector3.UP,Color("8de8cb"),20,1.3,1.6,0.04)

func tick(delta: float, combat_frozen := false) -> void:
	if delta <= 0 or combat_frozen: return
	for i in range(flash_lights.size()-1,-1,-1):
		var slot: Dictionary=flash_lights[i]
		slot.life=maxf(0,slot.life-delta)
		slot.node.light_energy=slot.energy*pow(slot.life/slot.total,1.7)
		slot.node.visible=slot.life>0
		if slot.life<=0:
			slot.node.queue_free()
			flash_lights.remove_at(i)
	var trails: Array[Dictionary] = []
	var arrivals: Array[Vector3] = []
	var landings: Array[Vector3] = []
	for i in range(effects.size()-1,-1,-1):
		var effect: Dictionary = effects[i]
		if not is_instance_valid(effect.node) or effect.node.is_queued_for_deletion():
			effects.remove_at(i)
			continue
		var node: MeshInstance3D = effect.node
		if effect.has("follow"):
			var target = effect.follow.get_ref()
			if not is_instance_valid(target) or target.is_queued_for_deletion():
				cancel(node)
				continue
			node.global_position = target.global_position+effect.get("follow_offset",Vector3.UP*0.055)
		if combat_frozen and (effect.critical or effect.mode == "travel"): continue
		var step_delta := delta
		if float(effect.get("delay",0.0)) > 0:
			effect.delay -= step_delta
			if effect.delay > 0: continue
			step_delta = -float(effect.delay)
			node.visible = true
		effect.life -= step_delta
		if effect.life <= 0 and effect.get("loop",false):
			effect.life = float(effect.total)+fmod(float(effect.life),float(effect.total))
			if not effect.has("follow"): node.position = effect.loop_position
		if effect.life <= 0:
			if effect.mode == "travel":
				node.global_position = effect.end
				if effect.get("arrival","") == "pickup": arrivals.append(effect.end)
			node.queue_free()
			effects.remove_at(i)
			continue
		var progress := 1.0-float(effect.life)/float(effect.total)
		if effect.has("mote_origin"):
			effect.flow_time += step_delta
			var clock: float = effect.flow_time
			var phase: float = effect.mote_phase
			node.position = effect.mote_origin+Vector3(sin(clock*0.7+phase)*0.18,sin(clock*0.9+phase)*0.16,cos(clock*0.6+phase)*0.16)
			node.scale = Vector3.ONE*(0.65+0.30*sin(clock*1.9+phase))
			# Distinct life phases prevent all ambient points blinking at once.
			node.material_override.set_shader_parameter("age",fposmod(clock+phase,2.4))
			continue
		if effect.has("charge_root"): node.scale = Vector3.ONE*lerpf(1.0,0.5,progress*progress)
		if effect.has("hover_origin"):
			effect.motion_time = float(effect.get("motion_time",0.0))+step_delta
			var base: Vector3 = effect.hover_origin
			if effect.has("follow"): base=node.global_position
			node.global_position=base+Vector3.UP*sin(float(effect.motion_time)*3.2)*0.08
		if effect.has("screen"):
			effect.screen.set_shader_parameter("age",float(effect.total)-float(effect.life))
			effect.screen_rect.size = get_viewport().get_visible_rect().size
			var camera := get_viewport().get_camera_3d()
			if camera: effect.screen.set_shader_parameter("center",camera.unproject_position(effect.screen_origin)/effect.screen_rect.size)
		if effect.mode == "painted_slash":
			node.material_override.set_shader_parameter("age",float(effect.total)-float(effect.life))
			continue
		node.position += effect.velocity*step_delta
		effect.velocity.y -= float(effect.gravity)*step_delta
		if effect.has("drag"): effect.velocity *= exp(-float(effect.drag)*step_delta)
		if effect.expansion != 0: node.scale = (node.scale+Vector3.ONE*float(effect.expansion)*step_delta).max(Vector3.ONE*0.001)
		if effect.has("spin"): node.rotation.y += float(effect.spin)*step_delta
		if effect.has("curve"):
			var u := 1.0-pow(1.0-progress,1.8)
			var points: Array = effect.curve
			node.global_position = points[0]*(1.0-u)*(1.0-u)+points[1]*2.0*(1.0-u)*u+points[2]*u*u
			node.scale = Vector3.ONE*(0.45+sin(progress*PI)*0.8)
		if effect.mode == "stamp":
			if effect.has("flow_time"):
				effect.flow_time += step_delta
				node.material_override.set_shader_parameter("age",effect.flow_time)
			else:
				node.material_override.set_shader_parameter("age",float(effect.total)-float(effect.life))
			continue
		var c: Color = effect.color
		c.a *= pow(1.0-progress,0.75)
		match effect.mode:
			"held": c.a = effect.color.a
			"expand": node.scale = effect.start_scale.lerp(effect.end_scale,1.0-pow(1.0-progress,3))
			"warning":
				c.a = 0.65+progress*0.35
				node.get_child(1).scale = Vector3(maxf(progress,0.05),1,maxf(progress,0.05))
				if node.get_child(0).material_override is ShaderMaterial:
					node.get_child(0).material_override.set_shader_parameter("progress",progress)
			"charge":
				node.scale = Vector3.ONE*lerpf(1.0,0.12,progress)
				c.a = 0.4+progress*0.6
			"travel":
				var previous_position:=node.global_position
				node.global_position = effect.start.lerp(effect.end,progress)
				if effect.has("travel_curve"):
					var u := 1.0-pow(1.0-progress,2.0)
					var pts: Array=effect.travel_curve
					node.global_position=pts[0]*(1.0-u)*(1.0-u)+pts[1]*2.0*u*(1.0-u)+pts[2]*u*u
				c.a = 1.0
				effect.trail_clock += step_delta
				if effect.trail_clock >= 0.035:
					effect.trail_clock = 0.0
					trails.append({"pos":node.global_position,"color":effect.color,"direction":(node.global_position-previous_position).normalized(),"width":effect.get("trail_width",0.18)})
			"drop":
				if node.position.y < float(effect.floor_y):
					node.position.y = effect.floor_y
					if effect.get("bounce_once",false):
						effect.velocity.y=0.9
						effect.bounce_once=false
						landings.append(node.global_position)
					else:
						effect.velocity = Vector3.ZERO
						effect.gravity = 0.0
		node.material_override.albedo_color = c
	for trail in trails:
		var tip: Vector3=trail.pos
		var direction: Vector3=trail.direction
		_path([tip-direction*0.75,tip-direction*0.35+Vector3.UP*0.04,tip],trail.width,trail.color,0.22,0,0,true)
	for landing in landings:
		stamp(landing,Vector2.ONE*0.7,Color("ff8a9c"),0.26,1,true)
	for pos in arrivals:
		_expand(pos-Vector3.UP*pos.y,0.55,Color("ff7085"),0.35)
		burst(pos,Vector3.UP,8,Color("ff7085"),1.5)
	_sync_source_lights()
