extends "res://scripts/environment/tartarus_reference_room.gd"
## R06 entrance composition. Reuses the measured room's material vocabulary.
var column_layout: Array[Vector3] = []

func build() -> void:
	layout={"bounds":[-7,-5,7,6],"pits":[],"columns":[],"mosaics":[[0,1]],"mosaic_sizes":[3.4]}
	rng.seed=6101
	kit=Kit.new()
	kit.name="EntryArchitecture"
	add_child(kit)
	details=preload("res://scripts/environment/tartarus_details.gd").new()
	details.name="PaintedDetails"
	add_child(details)
	kit.palette.stone.albedo_color=Color("555f66")
	kit.palette.gold.albedo_color=Color("9b8552")
	kit.palette.light.albedo_color=Color("969093")
	kit.palette.green.emission_energy_multiplier=.35
	_floor()
	_shell()
	_portal()
	_decal("GorgonMosaic","gorgon-mosaic.svg",Vector3(0,.028,1),Vector2(3.4,3.4))
	for x in [-3.1,3.1]:_brazier(Vector3(x,0,-2.55))
	details.urn_cluster(Vector3(-5.25,0,-2.65),1)
	details.urn_cluster(Vector3(4.6,0,3.9),3)
	for x in [-5.95,5.95]:_column(Vector3(x,0,-4.1),3.9)
	for x in [-4.2,4.2]:_banner(Vector3(x,3.25,-4.43))
	_debris()
	_threshold()
	_motes()
	for part in kit.get_children():
		if part is MeshInstance3D and part.get_meta("part","") in ["SideCoping","ColumnCapital","ThresholdStone"]:
			part.material_override=details.material("wall-stone.svg",Color(.75,.72,.78))

func _surface(file: String,color: Color=Color.WHITE,emission:=0.0) -> StandardMaterial3D:
	if file.begins_with("slate-") and emission==0:
		return details.material(file,Color(color.r*.95,color.g*.89,color.b*1.02))
	return super._surface(file,color,emission)

func _floor_band(start: float,end: float,z: float) -> void:
	# Reusable floor builder calls reference-wide bands. Clamp them to this room.
	super._floor_band(maxf(start,-6.7),minf(end,6.7),z)

func _shell() -> void:
	for x in [-4.65,4.65]:
		kit.box("RearWallMass",Vector3(4.7,3.7,.65),Vector3(x,1.72,-5.05),"dark",true).material_override=details.material("column-stone.svg",Color(.44,.49,.55))
		kit.box("RearCornice",Vector3(4.8,.16,.88),Vector3(x,3.52,-5.03),"black")
	for side in [-1,1]:
		for i in range(3):
			var x:float=side*(2.9+i*1.3)
			details.wall_panel(Vector3(x,.77,-4.66),1.26)
			kit.box("DadoCap",Vector3(1.29,.09,.4),Vector3(x,1.51,-4.62),"gold")
			var fresco:=QuadMesh.new()
			fresco.size=Vector2(1.1,1.52)
			kit.mesh_part("UpperRecessFresco",fresco,_surface("wall-fresco.svg",Color(.62,.51,.66)),Vector3(x,2.43,-4.715))
			kit.box("RecessTop",Vector3(1.2,.06,.12),Vector3(x,3.2,-4.64),"light")
		var x:float=side*7.0
		kit.box("SideParapet",Vector3(.32,.6,11),Vector3(x,.12,.5),"dark",true)
		kit.box("SideCoping",Vector3(.44,.09,11),Vector3(x,.47,.5),"light")
		for i in range(8):details.wall_panel(Vector3(x+side*.17,-.54,-4.2+i*1.31),1.28,side*PI/2)
	kit.box("FrontFoundation",Vector3(14,1.3,.4),Vector3(0,-.73,6),"dark",true)
	kit.box("FrontCoping",Vector3(14,.12,.37),Vector3(0,-.04,6),"black")
	for i in range(10):details.wall_panel(Vector3(-5.9+i*1.31,-.8,6.22),1.28)
	# Closed rear recess supports the door silhouette; no unbacked hole into the void.
	kit.box("DoorRecessBack",Vector3(4.8,4.7,.4),Vector3(0,2.2,-5.42),"black",true)

func _portal() -> void:
	var bronze:Material=details.material("bronze.svg",Color(.87,.72,.49))
	for x in [-2.05,2.05]:
		kit.box("PortalPier",Vector3(.62,3.9,1.0),Vector3(x,1.9,-4.67),"stone",true).material_override=details.material("column-stone.svg",Color(.73,.69,.72))
		for y in [.16,.4,3.45,3.68]:kit.box("PortalPierMoulding",Vector3(.8,.13,1.15),Vector3(x,y,-4.64),"gold").material_override=bronze
		kit.box("PortalInnerBevel",Vector3(.10,3.4,.12),Vector3(x-signf(x)*.34,1.83,-4.12),"gold")
	kit.box("PortalLintel",Vector3(5.05,.43,1.18),Vector3(0,3.91,-4.67),"stone",true).material_override=details.material("column-stone.svg",Color(.85,.77,.77))
	kit.box("PortalCrown",Vector3(5.3,.14,1.3),Vector3(0,4.2,-4.67),"gold").material_override=bronze
	for x in [-1.4,-.7,0,.7,1.4]:kit.meander(Vector3(x-.23,3.73,-4.04),true)
	# Two deep door leaves with recessed panels and raised bronze framework.
	for side in [-1,1]:
		var x:float=side*.82
		kit.box("DoorLeaf",Vector3(1.58,3.17,.23),Vector3(x,1.72,-4.9),"dark",true).material_override=details.material("bronze.svg",Color(.36,.43,.37))
		for dx in [-.7,.7]:kit.box("DoorStile",Vector3(.08,3.17,.08),Vector3(x+dx,1.72,-4.75),"gold").material_override=bronze
		for y in [.22,3.25]:kit.box("DoorRail",Vector3(1.47,.075,.1),Vector3(x,y,-4.72),"gold").material_override=bronze
		for y in [.59,1.95]:
			kit.box("DoorInset",Vector3(1.22,.61 if y<1 else 1.62,.025),Vector3(x,y,-4.76),"black")
		var relief:=QuadMesh.new()
		relief.size=Vector2(1.32,2.91)
		var paint:=StandardMaterial3D.new()
		var image:Image=load("res://assets/environment/entry06/door-relief.png").get_image()
		if image.is_compressed():image.decompress()
		image.generate_mipmaps()
		paint.albedo_texture=ImageTexture.create_from_image(image)
		paint.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		paint.albedo_color=Color(.97,.98,1.02)
		paint.roughness=.92
		kit.mesh_part("PaintedDoorRelief",relief,paint,Vector3(x,1.73,-4.69))
		var ring:=TorusMesh.new()
		ring.inner_radius=.12
		ring.outer_radius=.16
		ring.rings=24
		var handle=kit.mesh_part("DoorRingHandle",ring,bronze,Vector3(side*.23,1.43,-4.57))
		handle.rotation.x=PI/2
		for y in [.36,3.09]:
			for dx in [-.60,.60]:kit.cylinder("DoorRivet",.047,.035,Vector3(x+dx,y,-4.64),"gold").rotation.x=PI/2
	kit.box("DoorSeam",Vector3(.025,3.03,.015),Vector3(0,1.72,-4.735),"green")
	kit.box("CrestBacking",Vector3(1.5,.9,.23),Vector3(0,4.25,-4.18),"black")
	kit.skull(Vector3(0,4.32,-4.0),.66)
	for side in [-1,1]:
		var laurel:=PackedVector3Array()
		for i in range(13):
			var a:float=float(i)/12*1.9
			laurel.append(Vector3(side*(.47+sin(a)*.22),4.03+(1-cos(a))*.39,-3.96))
		kit.line("CrestLaurel",laurel,"gold",.042)
	kit.box("ThresholdStone",Vector3(3.55,.12,.9),Vector3(0,.035,-4.35),"stone",true)
	kit.box("ThresholdLip",Vector3(3.65,.05,.10),Vector3(0,.09,-3.94),"gold")

func _column(pos: Vector3,height: float) -> void:
	column_layout.append(pos)
	kit.box("ColumnPlinth",Vector3(1.17,.2,1.17),pos+Vector3.UP*.1,"black",true)
	kit.cylinder("ColumnFoot",.57,.20,pos+Vector3.UP*.29,"stone")
	kit.cylinder("EntryColumn",.45,height-.7,pos+Vector3.UP*(height*.5),"stone").material_override=details.material("column-stone.svg",Color(.71,.69,.75))
	var blocker=kit.box("ColumnBlocker",Vector3(.87,height,.87),pos+Vector3.UP*height*.5,"dark",true)
	blocker.hide()
	for y in [.44,height-.40]:kit.cylinder("ColumnCollar",.51,.09,pos+Vector3.UP*y,"gold")
	kit.box("ColumnCapital",Vector3(1.14,.19,1.14),pos+Vector3.UP*(height-.18),"light")

func _brazier(pos: Vector3) -> void:
	kit.box("BrazierPlinth",Vector3(.79,.17,.79),pos+Vector3.UP*.08,"black",true)
	kit.cylinder("BrazierStem",.17,.66,pos+Vector3.UP*.46,"gold")
	kit.cylinder("BrazierBowl",.18,.35,pos+Vector3.UP*.96,"gold",.47).material_override=details.material("bronze.svg",Color(.95,.82,.58))
	kit.cylinder("BrazierCoals",.42,.03,pos+Vector3.UP*1.15,"black")
	for i in range(3):
		var flame:=QuadMesh.new()
		flame.size=Vector2(.68,1.26)
		var mat:=ShaderMaterial.new()
		mat.shader=preload("res://shaders/tartarus_soul_fire.gdshader")
		mat.set_shader_parameter("phase",float(i)*2.1+pos.x)
		var node=kit.mesh_part("BrazierSoulFire",flame,mat,pos+Vector3((i-1)*.10,1.70,0))
		node.rotation.y=-PI/4+i*.65
	var light:=OmniLight3D.new()
	light.name="BrazierGlow"
	light.position=pos+Vector3.UP*1.7
	light.light_color=Color("72e6a6")
	light.light_energy=1.4
	light.omni_range=4.5
	light.shadow_enabled=true
	add_child(light)

func _threshold() -> void:
	for z in [-3.3,-2.95]:kit.box("ThresholdInlay",Vector3(3.5,.008,.055),Vector3(0,.012,z),"gold")
	for x in [-2.0,2.0]:
		kit.box("ApproachInlay",Vector3(.045,.008,6.2),Vector3(x,.012,.2),"gold")
	# A short spawn approach at the front frames the first shot.
	for x in [-1.3,1.3]:kit.meander(Vector3(x-.35,.015,4.8))

func _banner(pos:Vector3) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colors: Array[Color]=[Color("392333"),Color("75404d"),Color("512b3b"),Color("8b4c56")]
	for i in range(10):
		for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
			var n:int=i+corner.x
			var x:float=-.53+n*.106
			var bottom:float=-1.51+(.13 if n in [1,4,8] else 0)
			st.set_normal(Vector3.BACK)
			st.set_color(colors[n%4])
			st.add_vertex(pos+Vector3(x,bottom*corner.y,.048*sin(n*1.6)))
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.albedo_color=Color("752d44")
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.roughness=1
	kit.mesh_part("RaggedBanner",st.commit(),mat,Vector3.ZERO)
	kit.box("BannerRod",Vector3(1.26,.065,.10),pos+Vector3(0,.045,.02),"gold")
	for side in [-1,1]:
		kit.line("BannerGoldThread",PackedVector3Array([pos+Vector3(side*.43,-.08,.055),pos+Vector3(side*.43,-1.35,.055)]),"gold",.017)
	var emblem:=PackedVector3Array([pos+Vector3(0,-.25,.09),pos+Vector3(.21,-.63,.09),pos+Vector3(0,-1.0,.09),pos+Vector3(-.21,-.63,.09),pos+Vector3(0,-.25,.09)])
	kit.line("BannerDiamond",emblem,"gold",.024)

func _debris() -> void:
	for i in range(40):
		var x:float=rng.randf_range(-6.7,6.7)
		if absf(x)<2.6:continue
		var chip:=PrismMesh.new()
		chip.size=Vector3(rng.randf_range(.05,.16),rng.randf_range(.025,.07),rng.randf_range(.06,.17))
		kit.mesh_part("WallChips",chip,kit.palette.light,Vector3(x,.025,rng.randf_range(-4.6,-3.8))).rotation.y=rng.randf()*TAU

func _motes() -> void:
	var particles:=GPUParticles3D.new()
	particles.name="UnderworldMotes"
	particles.amount=32
	particles.lifetime=9
	particles.preprocess=9
	particles.visibility_aabb=AABB(Vector3(-7,-1,-5),Vector3(14,7,11))
	var process:=ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents=Vector3(6,.2,4)
	process.direction=Vector3.UP
	process.spread=22
	process.gravity=Vector3.ZERO
	process.initial_velocity_min=.06
	process.initial_velocity_max=.18
	process.scale_min=.012
	process.scale_max=.028
	particles.process_material=process
	var mesh:=SphereMesh.new()
	mesh.radius=1
	mesh.height=2
	mesh.radial_segments=6
	mesh.rings=3
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("829b76")
	mesh.material=material
	particles.draw_pass_1=mesh
	particles.position=Vector3(0,.15,.5)
	add_child(particles)

func spawn_positions() -> Array[Vector3]:
	return [Vector3(0,0,4.3),Vector3(-3,0,1),Vector3(3,0,1)]
