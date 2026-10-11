extends Node3D
## Screenshot 03 reconstruction. Geometry, decorations and source textures remain editable.
const Kit = preload("res://scripts/environment/tartarus_kit.gd")
const ROOT := "res://assets/environment/reference03/"
var layout: Dictionary
var rng := RandomNumberGenerator.new()
var kit: Node3D
var textures: Dictionary = {}
var details: Node3D

func build() -> void:
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/reference05/layout.json"))
	details=preload("res://scripts/environment/tartarus_details.gd").new()
	details.name="HandPaintedDetails"
	add_child(details)
	rng.seed=3303
	kit=Kit.new()
	kit.name="Reference03Architecture"
	add_child(kit)
	for pair in [["black","071416"],["dark","15272a"],["stone","667e74"],["light","77748a"],["gold","627559"],["bone","abb69b"]]:
		kit.palette[pair[0]].albedo_color=Color(pair[1])
	kit.palette.green.emission_energy_multiplier=.20
	kit.palette.green.albedo_color=Color("279965")
	_floor()
	for spec in layout.pits: _pit(spec)
	_back_wall()
	_front_wall()
	for i in range(layout.mosaics.size()):
		var pos: Array=layout.mosaics[i]
		var size: float=layout.mosaic_sizes[i]
		_decal("GorgonMosaic", "gorgon-mosaic.svg",Vector3(pos[0],.028,pos[1]),Vector2(size,size))
	_decal("SkullTrap","skull-trap.svg",Vector3(1,.26,2),Vector2(1.85,2.3))
	kit.box("TrapSlab",Vector3(1.92,.22,2.35),Vector3(1,.12,2),"stone",true)
	details.urn_cluster(Vector3(-8,0,-3.0),0)
	# Chipped fragments stay along architecture and off the main route.
	for i in range(48):
		var p:=Vector3(rng.randf_range(-8,10),.035,rng.randf_range(-4.4,-3.8))
		var chip:=PrismMesh.new()
		chip.size=Vector3(rng.randf_range(.04,.17),.07,rng.randf_range(.05,.2))
		kit.mesh_part("StoneChipping",chip,kit.palette.light,p).rotation.y=rng.randf()*TAU

func _texture(file: String) -> Texture2D:
	if not textures.has(file):
		# Use import remapping so the same surface works in editor and release PCK.
		textures[file]=load(ROOT+file) as Texture2D
	return textures[file]

func _surface(file: String, color: Color=Color.WHITE, emission:=0.0) -> StandardMaterial3D:
	if file.begins_with("slate-") and emission==0:return details.material(file,color)
	var mat:=StandardMaterial3D.new()
	if file in ["gorgon-mosaic.svg","skull-trap.svg","key-panel"]:
		if not textures.has("atlas"):
			textures.atlas=load(ROOT+"handpaint-atlas.png")
		mat.albedo_texture=textures.atlas
		mat.uv1_scale=Vector3(.491,.491,1)
		var offset:=Vector2(.004,.004)
		if file=="gorgon-mosaic.svg":offset.x+=.5
		if file=="key-panel":offset.y+=.5
		if file=="skull-trap.svg":offset+=Vector2(.5,.5)
		mat.uv1_offset=Vector3(offset.x,offset.y,0)
		if file=="gorgon-mosaic.svg":
			mat.uv1_scale=Vector3(.469,.469,1)
			mat.uv1_offset=Vector3(.515,.014,0)
	else:mat.albedo_texture=_texture(file)
	mat.albedo_color=color
	mat.roughness=1.0
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if emission>0:
		mat.emission_enabled=true
		mat.emission=color
		mat.emission_energy_multiplier=emission
	return mat

func _decal(label: String,file: String,pos: Vector3,size: Vector2) -> void:
	var plane:=PlaneMesh.new()
	plane.size=size
	var node=kit.mesh_part(label,plane,_surface(file),pos)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func is_pit(x: float,z: float) -> bool:
	for spec in layout.pits:
		var r: Array=spec.rect
		if x>r[0] and x<r[2] and z>r[1] and z<r[3]: return true
	return false

func _floor() -> void:
	var surfaces: Array[Material]=[]
	for i in range(16):surfaces.append(_surface("slate-%d.svg"%i,Color.from_hsv(.33+.028*(i%4),.13,.61+(i%5)*.049)))
	for x in range(int(layout.bounds[0]),int(layout.bounds[2])):
		for z in range(int(layout.bounds[1]),int(layout.bounds[3])):
			if is_pit(x+.5,z+.5):continue
			kit.box("FloorBody_%d_%d"%[x,z],Vector3(1,.65,1),Vector3(x+.5,-.34,z+.5),"dark",true)
			# Chipped outline made from eight points, not perfect rectangular tiles.
			var c:=rng.randf_range(.008,.045)
			var poly: Array[Vector2]=[Vector2(c,.012),Vector2(.98-c,.012),Vector2(.988,c),Vector2(.988,.985-c),Vector2(.98-c,.988),Vector2(c,.988),Vector2(.012,.985-c),Vector2(.012,c)]
			var st:=SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(1,poly.size()-1):
				for p in [poly[0],poly[i],poly[i+1]]:
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(1-p.x,p.y) if (x+z)%2 else p)
					st.add_vertex(Vector3(p.x,0,p.y))
			kit.mesh_part("ChippedSlate",st.commit(),surfaces[rng.randi_range(0,15)],Vector3(x,0,z))
	# Floor inlays reserve each mosaic footprint, and follow each pit separately.
	for spec in layout.pits:
		for z in [float(spec.rect[1])-.30,float(spec.rect[3])+.30]:
			_floor_band(spec.rect[0]-.25,spec.rect[2]+.25,z)
	_floor_band(-9.2,10.5,-4.55)
	_floor_band(-9.2,10.5,float(layout.bounds[3])-.3)

func decoration_clear(x: float,z: float,margin:=.18) -> bool:
	if x-margin<layout.bounds[0] or x+margin>layout.bounds[2] or z-margin<layout.bounds[1] or z+margin>layout.bounds[3]:return false
	for i in range(layout.mosaics.size()):
		var p: Array=layout.mosaics[i]
		var half: float=layout.mosaic_sizes[i]*.5
		if absf(x-p[0])<half+margin and absf(z-p[1])<half+margin:return false
	for spec in layout.pits:
		var r: Array=spec.rect
		if x+margin>r[0] and x-margin<r[2] and z+margin>r[1] and z-margin<r[3]:return false
	return true

func _floor_band(start: float,end: float,z: float) -> void:
	var run_start:=start
	var active:=false
	var count:=int(ceil((end-start)/.125))
	for i in range(count+1):
		var x:=minf(start+i*.125,end)
		var clear:=i<count and decoration_clear(x+.0625,z,.18)
		if clear and not active:
			run_start=x
			active=true
		if active and not clear:
			kit.box("FloorInlayBand",Vector3(x-run_start,.008,.22),Vector3((run_start+x)/2,.006,z),"gold")
			active=false
	for i in range(int(ceil(start)),int(floor(end))):
		if decoration_clear(i+.3,z,.2):
			var mark=kit.box("InlayDiamond",Vector3(.08,.008,.08),Vector3(i+.3,.014,z),"dark")
			mark.rotation.y=PI/4

func _pit(spec: Dictionary) -> void:
	var r: Array=spec.rect
	var cx: float=(r[0]+r[2])*.5
	var cz: float=(r[1]+r[3])*.5
	var depth: float=spec.depth
	var sx: float=r[2]-r[0]
	var sz: float=r[3]-r[1]
	kit.box(spec.id+"Bottom",Vector3(sx,.5,sz),Vector3(cx,-depth-.25,cz),"dark",true)
	for x in range(int(r[0]),int(r[2])):
		for z in range(int(r[1]),int(r[3])):
			var plane:=PlaneMesh.new()
			plane.size=Vector2(.97,.97)
			var mat:=_surface("slate-%d.svg"%((x+z+16)%8),Color("81b96a") if (x+z)%3 else Color("9ac37b"),.22)
			kit.mesh_part("SoulPitFloor",plane,mat,Vector3(x+.5,-depth+.015,z+.5))
	for z in [float(r[1]),float(r[3])]:
		kit.box("PitLining",Vector3(sx,depth,.16),Vector3(cx,-depth*.5,z),"light",true)
		kit.box("PitRim",Vector3(sx+.22,.22,.22),Vector3(cx,.035,z),"black",true)
		for x in range(int(r[0]),int(r[2])):
			var plane:=QuadMesh.new()
			plane.size=Vector2(.94,1.4)
			var part=kit.mesh_part("UnderworldFresco",plane,_surface("wall-fresco.svg",Color(.9,.75,1.25)),Vector3(x+.5,-.83,z+.091*(1 if z==r[1] else -1)))
			if z==r[3]:part.rotation.y=PI
	for x in [float(r[0]),float(r[2])]:
		kit.box("PitLining",Vector3(.16,depth,sz),Vector3(x,-depth*.5,cz),"light",true)
		kit.box("PitRim",Vector3(.22,.22,sz-.22),Vector3(x,.035,cz),"black",true)
		for z in range(int(r[1]),int(r[3])):
			var face:=QuadMesh.new()
			face.size=Vector2(.94,1.4)
			var part=kit.mesh_part("UnderworldFrescoSide",face,_surface("wall-fresco.svg",Color(.9,.75,1.25)),Vector3(x+.091*(1 if x==r[0] else -1),-.83,z+.5))
			part.rotation.y=PI/2 if x==r[0] else -PI/2
	for z in [float(r[1])+.1,float(r[3])-.1]:
		for y in [-.28,-1.5]:kit.box("PitHorizontalMoulding",Vector3(sx,.07,.09),Vector3(cx,y,z),"dark")
	for x in [float(r[0])+.1,float(r[2])-.1]:
		for y in [-.28,-1.5]:kit.box("PitHorizontalMoulding",Vector3(.09,.07,sz),Vector3(x,y,cz),"dark")
	var light:=OmniLight3D.new()
	light.position=Vector3(cx,-.45,cz)
	light.light_color=Color("9dff6a")
	light.light_energy=1.2
	light.omni_range=4.8
	add_child(light)
	for i in range(7):
		var flame:=QuadMesh.new()
		flame.size=Vector2(rng.randf_range(1.1,1.9),rng.randf_range(2.3,3.1))
		var mat:=ShaderMaterial.new()
		mat.shader=preload("res://shaders/tartarus_soul_fire.gdshader")
		mat.set_shader_parameter("phase",float(i)*1.7)
		var part=kit.mesh_part("RisingSoulFire",flame,mat,Vector3(cx+rng.randf_range(-sx*.3,sx*.3),-depth+flame.size.y*.5,cz+rng.randf_range(-sz*.28,sz*.28)))
		part.rotation.y=-PI/4

func _key_panel(pos: Vector3,width:=1.28) -> void:
	details.wall_panel(pos,width)

func _back_wall() -> void:
	kit.box("RearWall",Vector3(24,4.5,.8),Vector3(0,1.45,-5.6),"dark",true)
	kit.box("RearFoot",Vector3(24,.2,1.05),Vector3(0,.10,-4.8),"black",true)
	for i in range(18):_key_panel(Vector3(-11.5+i*1.31,.89,-4.49))
	kit.box("FriezeCap",Vector3(24,.15,.18),Vector3(0,1.66,-4.38),"black")
	for i in range(24):
		kit.box("FireChannelTile",Vector3(.96,.08,.9),Vector3(-11.5+i,1.62,-4.90),"green").material_override=_surface("slate-%d.svg"%(i%8),Color("78b798"),.22)
	for x in layout.columns:
		kit.cylinder("MassiveColumnFoot",.74,.22,Vector3(x,.2,-4.48),"stone")
		kit.cylinder("MassiveColumn",.70,4.2,Vector3(x,2.3,-4.58),"stone").material_override=details.material("column-stone.svg",Color(.72,.79,.76))
		for y in [.37,.49,3.8]:kit.cylinder("ColumnRing",.735,.07,Vector3(x,y,-4.58),"dark")
		kit.box("ColumnUpperBlock",Vector3(1.42,.3,1.42),Vector3(x,4.5,-4.58),"dark")
		var blocker=kit.box("ColumnCollision",Vector3(.95,3,.9),Vector3(x,1.5,-4.62),"stone",true)
		blocker.visible=false
	for i in range(8):
		var x: float=-8+i*2.55
		var light:=OmniLight3D.new()
		light.position=Vector3(x,2.0,-4.3)
		light.light_color=Color("36fda1")
		light.light_energy=.62
		light.omni_range=3.8
		add_child(light)
		var near_column:=false
		for cx in layout.columns:
			if absf(x-cx)<1.05:near_column=true
		if near_column:continue
		var flame:=QuadMesh.new()
		flame.size=Vector2(1.65,3.2)
		var mat:=ShaderMaterial.new()
		mat.shader=preload("res://shaders/tartarus_soul_fire.gdshader")
		mat.set_shader_parameter("phase",i*.5)
		kit.mesh_part("WallSoulFire",flame,mat,Vector3(x,2.65,-4.9))

func _front_wall() -> void:
	var length: float=layout.bounds[3]-layout.bounds[1]
	var cz: float=(layout.bounds[3]+layout.bounds[1])*.5
	kit.box("ForegroundWall",Vector3(.5,2.0,length),Vector3(-9.7,-1.0,cz),"dark",true)
	kit.box("ForegroundWalkway",Vector3(.85,.32,length),Vector3(-9.5,-.14,cz),"stone",true).material_override=details.material("column-stone.svg")
	for i in range(int(length/1.31)):details.wall_panel(Vector3(-9.98,-.85,-4.3+i*1.31),1.28,-PI/2)
	details.gate(Vector3(-9.6,0,.2))
	for x in [-9.8,11.0]:kit.box("SideBoundary",Vector3(.25,.3,length),Vector3(x,.02,cz),"black",true)
	var edge: float=layout.bounds[3]
	kit.box("OuterFoundation",Vector3(21,1.8,.45),Vector3(.5,-.92,edge),"dark",true)
	kit.box("OuterCoping",Vector3(21,.12,.32),Vector3(.5,-.035,edge),"black",true)
	for i in range(15):details.wall_panel(Vector3(-9.1+i*1.31,-.85,edge+.23),1.28,0)
func spawn_positions() -> Array[Vector3]:
	return [Vector3(-2,0,-2),Vector3(0,0,-2),Vector3(3,0,-2),Vector3(7,0,-2)]

