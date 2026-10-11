extends Node3D
## Shared gameplay lighting; room-owned accents are rebuilt on every transition.
const Atmosphere=preload("res://shaders/tartarus_atmosphere.gdshader")
var accents: Node3D
var fire_lights: Array[Dictionary]=[]
var clock:=0.0
var environment: Environment

func configure(game: Node3D) -> void:
	name="TartarusLighting"
	for child in game.get_children():
		if child is WorldEnvironment:
			environment=child.environment
			environment.background_color=Color("060b13")
			environment.ambient_light_color=Color("8797b0")
			environment.ambient_light_energy=.13
			environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
			environment.ssao_enabled=true
			environment.ssao_radius=.55
			environment.ssao_intensity=.7
			environment.ssao_power=1.0
			environment.glow_enabled=true
			environment.glow_intensity=.48
			environment.glow_bloom=0.0
			environment.glow_hdr_threshold=1.6
			environment.glow_hdr_scale=.9
		if child is DirectionalLight3D:
			if child.shadow_enabled:
				child.name="WarmKeyWithShadows"
				child.rotation_degrees=Vector3(-55,-35,0)
				child.light_color=Color("e4dcc5")
				child.light_energy=.28
				child.shadow_opacity=.22
				child.light_angular_distance=2.5
				child.directional_shadow_max_distance=55
				child.shadow_bias=.035
				child.shadow_normal_bias=.35
			else:
				child.name="CoolRimFill"
				child.light_color=Color("899ed5")
				child.light_energy=.10
	# Preserve actor readability in architectural shade without lifting the room.
	var actor_fill:=DirectionalLight3D.new()
	actor_fill.name="ActorPaintFill"
	actor_fill.light_cull_mask=2
	actor_fill.rotation_degrees=Vector3(-50,-35,0)
	actor_fill.light_color=Color("dbe7fa")
	actor_fill.light_energy=.70
	add_child(actor_fill)

func room_loaded(room: Node3D, index: int) -> void:
	if is_instance_valid(accents):
		remove_child(accents)
		accents.queue_free()
	accents=Node3D.new()
	accents.name="RoomLighting"
	add_child(accents)
	fire_lights.clear()
	clock=0
	_register_fire(room)
	if index==1:
		_spot(Vector3(-4,7,0),Vector3(-2,0,1.5),Color("d5ce9b"),3.0,10,30)
		_spot(Vector3(5,7,4),Vector3(5,0,2),Color("e4c592"),2.2,10,28)
		for spec in room.layout.pits:
			var r: Array=spec.rect
			var center:=Vector3((r[0]+r[2])*.5,.45,(r[1]+r[3])*.5)
			# Above-rim bounce illuminates the adjacent floor; deep lights cannot.
			var bounce:=OmniLight3D.new()
			bounce.name="SoulPitBounce"
			bounce.position=center
			bounce.light_color=Color("79ff53")
			bounce.light_energy=4.2
			bounce.omni_range=6.0
			bounce.omni_attenuation=2.0
			# This is reflected light, not another hard-shadow-casting point source.
			bounce.shadow_enabled=false
			bounce.light_size=1.2
			bounce.shadow_normal_bias=.35
			accents.add_child(bounce)
			fire_lights.append({"node":bounce,"energy":4.2,"phase":center.x})
			_bounce(center+Vector3(0,1.0,0),Color("43bfa0"),.45,6.0)
			# A broad luminous pool radiates along its rim, not only from its center.
			# Small overlapping sources keep the adjacent walkway bright and let the
			# contribution decay naturally a few tiles away from the fire.
			for edge in [Vector3(r[0]+.35,.65,center.z),Vector3(r[2]-.35,.65,center.z),Vector3(center.x,.65,r[1]+.35),Vector3(center.x,.65,r[3]-.35)]:
				_bounce(edge,Color("75ed78"),1.15,3.6)
			_mist(center+Vector3.UP*.1,Vector2(r[2]-r[0]+.8,r[3]-r[1]+.8),Color(.16,.65,.35,.13))
		_motes(Vector3(0,.8,1),Vector3(9,.5,5),60)
	else:
		_spot(Vector3(-1,6,-3.5),Vector3(0,0,-1.6),Color("ffe2a2"),5.0,10,42)
		_spot(Vector3(1,7,4.4),Vector3(0,0,2.8),Color("bbc7e0"),3.5,11,45)
		for x in [-.72,.65]:
			var ray:=MeshInstance3D.new()
			ray.name="DoorLightShaft"
			var quad:=QuadMesh.new()
			quad.size=Vector2(1.8,5.2)
			ray.mesh=quad
			ray.position=Vector3(x,2.2,-3.1)
			ray.rotation_degrees=Vector3(-22,-45,-12)
			var material:=ShaderMaterial.new()
			material.shader=Atmosphere
			material.set_shader_parameter("shaft",true)
			material.set_shader_parameter("tint",Color(1,.77,.39,.075))
			ray.material_override=material
			ray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			accents.add_child(ray)
		_mist(Vector3(0,.1,-3.4),Vector2(4,2),Color(.48,.52,.7,.065))
	# Raise only emissive source surfaces, never wash out the ordinary stone.
	for part in room.kit.get_children():
		if not part is MeshInstance3D:continue
		var label: String=part.get_meta("part","")
		if label=="RisingSoulFire":
			part.position.y+=.9
			part.scale.x=1.15
			part.scale.y=1.18
			part.material_override.set_shader_parameter("intensity",1.0)
		if label.ends_with("SoulFire"):
			part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if label in ["SoulPitFloor","FireChannelTile"]:
			var mat: StandardMaterial3D=part.material_override
			mat.emission_enabled=true
			mat.emission=Color("71f735") if label=="SoulPitFloor" else Color("32e39b")
			mat.emission_texture=mat.albedo_texture
			mat.emission_energy_multiplier=.72 if label=="SoulPitFloor" else .13

func _register_fire(node: Node) -> void:
	for child in node.get_children():
		if child is OmniLight3D:
			child.light_energy*=1.4
			child.omni_attenuation=2.0
			fire_lights.append({"node":child,"energy":child.light_energy,"phase":float(fire_lights.size())*1.73})
			child.light_size=.7
			child.shadow_opacity=.2
			child.omni_range*=1.15
			if child.position.y>0:
				_bounce(child.global_position+Vector3(0,.1,.4),Color("51c698"),.45,4.8)
		_register_fire(child)

func _bounce(pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var light:=OmniLight3D.new()
	light.name="DiffuseFireBounce"
	light.position=pos
	light.light_color=color
	light.light_energy=energy
	light.omni_range=radius
	light.omni_attenuation=2.0
	light.shadow_enabled=false
	accents.add_child(light)

func _spot(pos: Vector3, target: Vector3, color: Color, energy: float, reach: float, angle: float) -> void:
	var light:=SpotLight3D.new()
	light.name="ArchitecturalPool"
	accents.add_child(light)
	light.position=pos
	light.look_at(target)
	light.light_color=color
	light.light_energy=energy
	light.spot_range=reach
	light.spot_angle=angle
	light.spot_attenuation=1.1
	light.spot_angle_attenuation=.65
	light.shadow_enabled=true
	light.shadow_opacity=.18
	light.shadow_bias=.025
	light.shadow_normal_bias=.45
	light.light_size=1.0

func _mist(pos: Vector3, size: Vector2, color: Color) -> void:
	var node:=MeshInstance3D.new()
	node.name="LocalSoulHaze"
	var plane:=PlaneMesh.new()
	plane.size=size
	node.mesh=plane
	node.position=pos
	var material:=ShaderMaterial.new()
	material.shader=Atmosphere
	material.set_shader_parameter("tint",color)
	material.set_shader_parameter("phase",pos.x)
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	accents.add_child(node)

func _motes(pos: Vector3, bounds: Vector3, amount: int) -> void:
	var particles:=GPUParticles3D.new()
	particles.name="SoulEmbers"
	particles.amount=amount
	particles.lifetime=7
	particles.preprocess=7
	particles.position=pos
	particles.visibility_aabb=AABB(-bounds-Vector3.ONE,bounds*2+Vector3.ONE*4)
	var motion:=ParticleProcessMaterial.new()
	motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents=bounds
	motion.direction=Vector3.UP
	motion.spread=30
	motion.gravity=Vector3.ZERO
	motion.initial_velocity_min=.08
	motion.initial_velocity_max=.28
	motion.scale_min=.012
	motion.scale_max=.026
	particles.process_material=motion
	var mesh:=SphereMesh.new()
	mesh.radius=1
	mesh.height=2
	mesh.radial_segments=4
	mesh.rings=2
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("c4f5ac")
	material.emission_enabled=true
	material.emission=Color("8dea69")
	material.emission_energy_multiplier=1.8
	mesh.material=material
	particles.draw_pass_1=mesh
	accents.add_child(particles)

func tick(delta: float) -> void:
	clock+=delta
	for fire in fire_lights:
		if is_instance_valid(fire.node):
			fire.node.light_energy=fire.energy*(1+.06*sin(clock*6.7+fire.phase)+.035*sin(clock*11.3+fire.phase*2))
