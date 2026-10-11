extends Node3D
## R04: thickness, sculpted silhouettes, inked materials and correctly wrapped pottery.
const Kit=preload("res://scripts/environment/tartarus_kit.gd")
const ROOT="res://assets/environment/reference04/"
var mats: Dictionary={}

func material(file: String,tint: Color=Color.WHITE) -> StandardMaterial3D:
	var id:=file+str(tint)
	if mats.has(id):return mats[id]
	var mat:=StandardMaterial3D.new()
	# Imported SVGs are textures in release PCKs; raw source text is not retained.
	mat.albedo_texture=load(ROOT+file) as Texture2D
	mat.albedo_color=tint
	mat.roughness=1
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mats[id]=mat
	return mat

func urn_cluster(pos: Vector3,variant:=0) -> void:
	var group:=Node3D.new()
	group.name="PaintedAmphoraCluster"
	group.position=pos
	add_child(group)
	var placements: Array[Vector3]=[Vector3(-.85,.24,.66),Vector3(.12,.24,.85),Vector3(1.06,.15,.67),Vector3(-.60,-.74,1.01),Vector3(.46,-.85,.72),Vector3(1.43,-.80,.83)]
	for i in range(placements.size()):
		var jar=Kit.new()
		jar.name="PaintedAmphora%d"%i
		var placement: Vector3=placements[i]
		jar.position=Vector3(placement.x,0,placement.y)
		jar.rotation.y=.55*i+variant
		jar.scale=Vector3(.9 if i%3==2 else 1.0,1.10 if i%3==2 else 1.0,.9 if i%3==2 else 1.0)*placement.z
		group.add_child(jar)
		jar.palette.gold.albedo_color=Color("b6917b")
		jar.palette.dark.albedo_color=Color("182726")
		var profile: Array[Vector2]=[Vector2(.17,0),Vector2(.22,.05),Vector2(.22,.11),Vector2(.15,.17),Vector2(.22,.31),Vector2(.34,.48),Vector2(.43,.7),Vector2(.44,.84),Vector2(.4,.98),Vector2(.29,1.09),Vector2(.15,1.16),Vector2(.14,1.35),Vector2(.21,1.37),Vector2(.21,1.43),Vector2(.145,1.43),Vector2(.13,1.28)]
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in range(profile.size()-1):
			for seg in range(40):
				for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var p: Vector2=profile[row+corner.y]
					var a:float=TAU*(seg+corner.x)/40
					var delta: Vector2=profile[row+1]-profile[row]
					st.set_normal(Vector3(sin(a)*delta.y,-delta.x,cos(a)*delta.y).normalized())
					st.set_uv(Vector2(float(seg+corner.x)/40,1-p.y/1.43))
					st.add_vertex(Vector3(sin(a)*p.x,p.y,cos(a)*p.x))
		jar.mesh_part("WrappedCeramic",st.commit(),material("urn-painted-wrap.png",Color(1.15,1.08,1.03)),Vector3.ZERO)
		jar.cylinder("HollowMouth",.13,.02,Vector3(0,1.28,0),"black")
		for side in [-1,1]:
			var points:=PackedVector3Array()
			for j in range(19):
				var t:float=float(j)/18
				points.append(Vector3(side*(.16+sin(t*PI)*.29),1.3-t*.42,0))
			jar.line("AmphoraHandle",points,"dark",.062)
		jar.cylinder("PaintedFootRing",.221,.018,Vector3(0,.12,0),"gold")
		var lip:=TorusMesh.new()
		lip.inner_radius=.146
		lip.outer_radius=.215
		lip.rings=40
		lip.ring_segments=8
		jar.mesh_part("OpenCeramicLip",lip,jar.palette.gold,Vector3(0,1.415,0))

func wall_panel(pos: Vector3,width:=1.28,turn:=0.0) -> void:
	var panel=Kit.new()
	panel.name="CarvedWallPanel"
	panel.position=pos
	panel.rotation.y=turn
	add_child(panel)
	panel.palette.stone.albedo_color=Color("9186a2")
	panel.palette.light.albedo_color=Color("aaa997")
	panel.palette.dark.albedo_color=Color("152525")
	panel.box("ThickStoneBlock",Vector3(width,1.35,.3),Vector3.ZERO,"stone").material_override=material("wall-stone.svg",Color(.91,.83,1.02))
	panel.box("InsetShadow",Vector3(width-.20,1.07,.04),Vector3(0,0,.171),"dark")
	panel.box("InsetFace",Vector3(width-.32,.95,.035),Vector3(.02,-.012,.195),"stone").material_override=material("wall-stone.svg",Color(.72,.73,.77))
	# Square spiral protrudes from the inset; dark side faces and chipped painted front.
	var points:=PackedVector3Array([Vector3(-.42,-.46,.245),Vector3(-.42,.45,.245),Vector3(.4,.45,.245),Vector3(.4,-.39,.245),Vector3(-.2,-.39,.245),Vector3(-.2,.20,.245),Vector3(.18,.20,.245),Vector3(.18,-.15,.245)])
	for i in range(points.size()-1):
		var a:=points[i];var b:=points[i+1];var delta:=b-a
		panel.box("CarvedMeander",Vector3(absf(delta.x)+.105,absf(delta.y)+.105,.15),(a+b)/2,"stone")
	panel.box("UpperBevel",Vector3(width-.03,.055,.35),Vector3(0,.646,.035),"light")
	panel.box("LowerRecess",Vector3(width,.055,.32),Vector3(0,-.655,.035),"dark")

func gate(pos: Vector3) -> Node3D:
	var g=Kit.new()
	g.name="ForegroundExit"
	g.position=pos
	g.rotation.y=PI/2
	add_child(g)
	g.palette.gold.albedo_color=Color("99945c")
	g.palette.stone.albedo_color=Color("686947")
	g.palette.dark.albedo_color=Color("1d2926")
	for x in [-.88,.88]:
		g.box("GatePier",Vector3(.23,1.6,.42),Vector3(x,.78,0),"stone",true).material_override=material("bronze.svg")
		g.box("PierBase",Vector3(.39,.16,.56),Vector3(x,.08,0),"dark",true)
		for y in [.18,.92,1.43,1.56]:g.box("PierMoulding",Vector3(.30,.065,.49),Vector3(x,y,0),"gold")
	for x in [-.43,.43]:
		g.box("LowerDoorLeaf",Vector3(.80,.96,.31),Vector3(x,.50,0),"stone",true).material_override=material("bronze.svg",Color(.72,.78,.64))
		for face in [-1,1]:
			g.box("DoorInset",Vector3(.58,.65,.04),Vector3(x,.50,face*.175),"dark")
			var points:=PackedVector3Array([Vector3(x-.2,.25,face*.205),Vector3(x-.2,.74,face*.205),Vector3(x+.2,.74,face*.205),Vector3(x+.2,.35,face*.205),Vector3(x-.03,.35,face*.205),Vector3(x-.03,.57,face*.205),Vector3(x+.09,.57,face*.205)])
			g.line("DoorEngraving",points,"gold",.034)
	for x in [-.6,-.3,0,.3,.6]:
		g.cylinder("Baluster",.036,.49,Vector3(x,1.23,0),"gold")
		for y in [1.0,1.40]:g.cylinder("BalusterCollar",.065,.055,Vector3(x,y,0),"stone")
	for y in [.96,1.49,1.60]:
		g.box("GateCrossRail",Vector3(2.03,.075,.48),Vector3(0,y,0),"stone",true).material_override=material("bronze.svg")
	for side in [-1,1]:
		var path:=PackedVector2Array()
		for i in range(66):
			var t:=float(i)/65
			var a:float=-PI/2+t*TAU*1.08
			var radius:float=.64*(1-t)+.085*t
			path.append(Vector2(side*(.45+cos(a)*radius),2.19+sin(a)*radius))
		_volute(g,path,.125,.42)
	return g

func _volute(parent: Node3D,path: PackedVector2Array,width: float,depth: float) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(path.size()-1):
		var tangent: Vector2=(path[i+1]-path[maxi(0,i-1)]).normalized()
		var end_tangent: Vector2=(path[mini(path.size()-1,i+2)]-path[i]).normalized()
		var n:=Vector2(-tangent.y,tangent.x)*width*lerpf(1.0,.28,float(i)/(path.size()-1))
		var end_n:=Vector2(-end_tangent.y,end_tangent.x)*width*lerpf(1.0,.28,float(i+1)/(path.size()-1))
		var corners: Array[Vector3]=[]
		for z in [-depth/2,depth/2]:
			for p in [path[i]-n,path[i]+n,path[i+1]+end_n,path[i+1]-end_n]:corners.append(Vector3(p.x,p.y,z))
		var faces: Array=[[0,1,2,0,2,3],[4,7,6,4,6,5],[1,5,6,1,6,2],[3,7,4,3,4,0]]
		if i==0:faces.append([0,4,5,0,5,1])
		if i==path.size()-2:faces.append([2,6,7,2,7,3])
		for indices in faces:
			for k in indices:
				var v: Vector3=corners[k]
				st.set_uv(Vector2(v.x*.4+.5,v.y*.4))
				st.add_vertex(v)
	st.generate_normals()
	parent.mesh_part("ExtrudedVolute",st.commit(),material("bronze.svg",Color(1.12,1.13,.88)),Vector3.ZERO)
	# Dark ink follows the face, keeping the spiral readable at gameplay scale.
	for z in [-depth/2-.007,depth/2+.007]:
		var outline:=PackedVector3Array()
		for p in path:outline.append(Vector3(p.x,p.y,z))
		parent.line("VoluteInk",outline,"dark",.025)
