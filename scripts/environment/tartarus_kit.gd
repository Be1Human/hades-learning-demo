extends Node3D
## Named reusable parts; structural boxes own matching collision shapes.
var palette: Dictionary = {}
var flame_nodes: Array[MeshInstance3D] = []
var lights: Array[OmniLight3D] = []
var time := 0.0

func _init() -> void:
	for entry in [["stone","445c58"],["light","76817a"],["dark","192a2b"],["black","0d171e"],["gold","a28d53"],["red","6c233e"],["bone","a8b889"],["green","3afa8a"]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(entry[1])
		material.roughness = 0.88
		if entry[0] == "gold": material.metallic = 0.25
		if entry[0] == "green":
			material.emission_enabled = true
			material.emission = Color("48ff96")
			material.emission_energy_multiplier = 2.0
		palette[entry[0]] = material

func mesh_part(label: String, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.set_meta("part",label)
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	add_child(node)
	return node

func box(label: String, size: Vector3, pos: Vector3, color: String, collision := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var node := mesh_part(label,shape,palette[color],pos)
	if collision:
		var body := StaticBody3D.new()
		body.name = label + "Collision"
		body.collision_layer = 1
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collider.shape = bounds
		body.add_child(collider)
		node.add_child(body)
	return node

func cylinder(label: String, radius: float, height: float, pos: Vector3, color: String, top := -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius if top < 0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	return mesh_part(label,shape,palette[color],pos)

func line(label: String, points: PackedVector3Array, color: String, width := 0.035) -> void:
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		var segment := box(label,Vector3(width,width,a.distance_to(b)),(a+b)/2,color)
		segment.basis = Basis.looking_at(b-a,Vector3.UP if absf((b-a).normalized().y)<0.99 else Vector3.RIGHT)

func meander(pos: Vector3, vertical := false, count := 1) -> void:
	for i in range(count):
		var points := PackedVector3Array()
		for p in [Vector2(0,0),Vector2(.68,0),Vector2(.68,.62),Vector2(.15,.62),Vector2(.15,.18),Vector2(.48,.18),Vector2(.48,.43)]:
			points.append(pos + (Vector3(p.x+i*.85,p.y,0) if vertical else Vector3(p.x+i*.85,0,p.y)))
		line("GreekKey",points,"gold",.045)

func skull(pos: Vector3, scale_value := 1.0) -> void:
	var head := SphereMesh.new()
	head.radius = .43
	head.height = .87
	head.radial_segments = 8
	head.rings = 4
	mesh_part("SkullBrow",head,palette.bone,pos).scale = Vector3(1,.96,.43)*scale_value
	for side in [-1,1]:
		var socket := box("EyeSocket",Vector3(.24,.18,.035)*scale_value,pos+Vector3(side*.20,.06,.19)*scale_value,"black")
		socket.rotation.z = side*.18
		box("SoulEye",Vector3(.11,.07,.045)*scale_value,pos+Vector3(side*.20,.07,.214)*scale_value,"green")
	box("Nose",Vector3(.09,.15,.04)*scale_value,pos+Vector3(0,-.12,.22)*scale_value,"black").rotation.z = .5
	for i in range(5):
		box("Tooth",Vector3(.086,.18,.13)*scale_value,pos+Vector3((i-2)*.09,-.39,.12)*scale_value,"bone")

func flame(pos: Vector3, size := 1.0) -> void:
	for i in range(3):
		var shape := PrismMesh.new()
		shape.size = Vector3(.28,.8,.26)*size
		var node := mesh_part("SoulFlame",shape,palette.green,pos+Vector3((i-1)*.15,.13*abs(i-1),0)*size)
		node.rotation.z = (i-1)*.22
		flame_nodes.append(node)
	var light := OmniLight3D.new()
	light.position = pos+Vector3.UP*.3
	light.light_color = Color("3effa0")
	light.light_energy = 2.0
	light.omni_range = 5.0*size
	add_child(light)
	lights.append(light)

func warden() -> void:
	box("Foot",Vector3(1.9,.20,1.9),Vector3(0,.02,0),"black",true)
	box("LowerPlinth",Vector3(1.65,.26,1.65),Vector3(0,.25,0),"light",true)
	box("KeyBand",Vector3(1.48,.70,1.48),Vector3(0,.73,0),"dark",true)
	meander(Vector3(-.65,.43,.754),true)
	box("CrownBase",Vector3(1.65,.18,1.65),Vector3(0,1.16,0),"gold",true)
	box("SoulObelisk",Vector3(1.16,1.2,1.16),Vector3(0,1.84,0),"dark",true)
	skull(Vector3(0,1.92,.60),1.15)
	for side in [-1,1]:
		var horn := PrismMesh.new()
		horn.size = Vector3(.29,.92,.48)
		mesh_part("Horn",horn,palette.light,Vector3(side*.61,2.48,.18)).rotation.z = -side*.25
	box("CrownRim",Vector3(1.48,.14,1.48),Vector3(0,2.51,0),"gold")
	flame(Vector3(0,2.98,0),.85)

func brazier() -> void:
	box("BrazierFoot",Vector3(.85,.24,.85),Vector3(0,.12,0),"black",true)
	cylinder("Stem",.16,.68,Vector3(0,.57,0),"gold")
	cylinder("Bowl",.22,.32,Vector3(0,1.02,0),"gold",.55)
	cylinder("Coals",.46,.05,Vector3(0,1.20,0),"black")
	flame(Vector3(0,1.57,0))

func pillar() -> void:
	box("Foot",Vector3(1.5,.30,1.35),Vector3(0,.1,0),"dark",true)
	cylinder("Shaft",.46,3.1,Vector3(0,1.8,0),"light")
	for i in range(10):
		var angle := TAU*i/10
		cylinder("Flute",.038,2.9,Vector3(sin(angle)*.45,1.8,cos(angle)*.45),"dark")
	box("Capital",Vector3(1.3,.23,1.18),Vector3(0,3.35,0),"gold")
	box("Abacus",Vector3(1.5,.22,1.35),Vector3(0,3.57,0),"dark")

func banner() -> void:
	box("CrimsonCloth",Vector3(1.05,1.9,.055),Vector3(0,2.2,0),"red")
	for side in [-1,1]:
		box("GoldHem",Vector3(.035,1.95,.065),Vector3(side*.48,2.2,.02),"gold")
	box("BannerRod",Vector3(1.3,.09,.12),Vector3(0,3.2,.05),"gold")
	skull(Vector3(0,2.38,.09),.57)

func gate() -> void:
	box("SealedDoor",Vector3(3.6,3.5,.55),Vector3(0,1.6,0),"black",true)
	for side in [-1,1]:
		box("GatePier",Vector3(.55,3.8,.95),Vector3(side*2,1.75,0),"dark",true)
		box("GateTrim",Vector3(.10,3.9,1),Vector3(side*2.1,1.8,0),"gold")
	box("Lintel",Vector3(4.85,.5,1.0),Vector3(0,3.85,0),"light",true)
	box("Crest",Vector3(1.45,.9,.5),Vector3(0,4.25,.1),"dark")
	skull(Vector3(0,4.25,.43),.8)
	for x in range(-5,6):
		box("GateBar",Vector3(.085,3.0,.14),Vector3(x*.31,1.75,.36),"gold")
	for y in [.5,1.1,2.8]:
		box("Crossbar",Vector3(3.4,.075,.18),Vector3(0,y,.39),"gold")
	for side in [-1,1]:
		for i in range(10):
			var link := TorusMesh.new()
			link.inner_radius = .052
			link.outer_radius = .09
			link.rings = 8
			link.ring_segments = 4
			var node := mesh_part("SealingChain",link,palette.gold,Vector3(side*(.13+i*.13),1.7+i*.07,.52))
			node.rotation_degrees = Vector3(75,0,side*60)

func urns() -> void:
	for i in range(3):
		var pos := Vector3((i-1)*.55,0,.35*(i%2))
		cylinder("UrnFoot",.22,.10,pos+Vector3.UP*.05,"gold")
		cylinder("UrnBody",.19,.52,pos+Vector3.UP*.36,"dark",.37)
		cylinder("UrnShoulder",.37,.20,pos+Vector3.UP*.72,"dark",.17)
		cylinder("UrnNeck",.16,.25,pos+Vector3.UP*.92,"gold")
		cylinder("UrnLip",.22,.065,pos+Vector3.UP*1.06,"gold")
		cylinder("UrnOpening",.16,.012,pos+Vector3.UP*1.10,"black")
		cylinder("UrnBand",.33,.085,pos+Vector3.UP*.56,"gold")

func _process(delta: float) -> void:
	time += delta
	for i in range(flame_nodes.size()):
		flame_nodes[i].scale.y = 1+.18*sin(time*7+i*1.4)
	for i in range(lights.size()):
		lights[i].light_energy = 1.9+.10*sin(time*9+i)
