extends Node3D
const Kit = preload("res://scripts/environment/tartarus_kit.gd")
var layout: Dictionary
var rng := RandomNumberGenerator.new()

func build() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/tartarus-room.json"))
	assert(layout.id == "tartarus-chamber-01")
	rng.seed = int(layout.seed)
	var masonry = Kit.new()
	masonry.name = "RoomStructure"
	add_child(masonry)
	_floor(masonry)
	_walls(masonry)
	for spec in layout.instances:
		var instance = Kit.new()
		instance.name = spec.id
		instance.set_meta("prefab",spec.prefab)
		instance.position = Vector3(spec.position[0],spec.position[1],spec.position[2])
		add_child(instance)
		instance.call(spec.prefab)

func _floor(kit: Node3D) -> void:
	kit.box("Foundation",Vector3(24,1,16),Vector3(0,-.62,0),"black",true)
	for i in range(7):
		var material: StandardMaterial3D = kit.palette.stone.duplicate()
		material.albedo_color = Color.from_hsv(.43+.009*i,.16,.31+.032*i)
		kit.palette["tile%d"%i] = material
	for x in range(16):
		for z in range(11):
			var pos := Vector3(-11.25+x*1.5,-.13,-6.65+z*1.33)
			kit.box("Tile_%02d_%02d"%[x,z],Vector3(1.474,.18,1.304),pos,"tile%d"%rng.randi_range(0,6))
			if rng.randf() < .52:
				var start := pos+Vector3(rng.randf_range(-.6,.1),.095,-.6)
				kit.line("SlateFracture",PackedVector3Array([start,start+Vector3(.19,0,.36),start+Vector3(.08,0,.62)]),"black",.016)
	for z in [-5.4,5.4]:
		kit.box("BorderBand",Vector3(21,.03,1.02),Vector3(0,-.025,z),"light")
		kit.meander(Vector3(-10.1,0,z-.31),false,24)
		for offset in [-.49,.49]:
			kit.box("BorderRule",Vector3(21,.025,.045),Vector3(0,0,z+offset),"gold")
	for x in [-10.45,10.45]:
		kit.box("SideBand",Vector3(.65,.035,10),Vector3(x,-.02,0),"dark")
	for radius in [2.75,2.83]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius-.025
		ring.outer_radius = radius
		ring.rings = 64
		ring.ring_segments = 4
		kit.mesh_part("SealRing",ring,kit.palette.gold,Vector3(0,-.018,0)).scale.y = .25
	for i in range(12):
		var angle := TAU*i/12
		var petal = kit.box("Laurel",Vector3(.22,.018,.64),Vector3(sin(angle)*2.36,-.005,cos(angle)*2.36),"gold")
		petal.rotation.y = angle+.48
	var diamond = kit.box("SealDiamond",Vector3(1.25,.022,1.25),Vector3(0,-.005,0),"dark")
	diamond.rotation.y = PI/4
	for i in range(4):
		var a := PI/2*i
		var marker = kit.box("SealPoint",Vector3(.07,.026,1.05),Vector3(sin(a)*.75,.005,cos(a)*.75),"gold")
		marker.rotation.y = a
	for z in [-7.8,7.8]:
		kit.box("Perimeter",Vector3(24,.5,.4),Vector3(0,.13,z),"dark",true)
		kit.box("PerimeterLip",Vector3(24,.08,.47),Vector3(0,.42,z),"gold")
	for x in [-11.8,11.8]:
		kit.box("Perimeter",Vector3(.4,.5,16),Vector3(x,.13,0),"dark",true)
		kit.box("PerimeterLip",Vector3(.47,.08,16),Vector3(x,.42,0),"gold")

func _walls(kit: Node3D) -> void:
	kit.box("NorthWall",Vector3(24,3.6,.8),Vector3(0,1.7,-8),"dark",true)
	kit.box("WestWall",Vector3(.8,3.6,16),Vector3(-12,1.7,0),"dark",true)
	for row in range(4):
		for col in range(15):
			var x := -11.2+col*1.6
			if absf(x)<2.4: continue
			kit.box("NorthAshlar",Vector3(1.55,.61,.12),Vector3(x,.38+row*.66,-7.55),"stone" if (col+row)%3 else "light")
		for col in range(10):
			kit.box("WestAshlar",Vector3(.12,.61,1.55),Vector3(-11.55,.38+row*.66,-7.2+col*1.6),"stone" if (col+row)%3 else "light")
	kit.box("NorthFrieze",Vector3(24,.76,.20),Vector3(0,2.95,-7.5),"black")
	kit.meander(Vector3(-11.5,2.63,-7.385),true,27)
	kit.box("NorthCornice",Vector3(24.6,.23,1.05),Vector3(0,3.55,-8),"gold")
	kit.box("WestCornice",Vector3(1.05,.23,16.5),Vector3(-12,3.55,0),"gold")
	for x in [-10.6,-5.3,5.3,10.6]:
		var pillar = Kit.new()
		pillar.name = "NorthPilaster_%s"%x
		pillar.position = Vector3(x,0,-7.55)
		add_child(pillar)
		pillar.pillar()
	for x in [-8,-3.1,3.1,8]:
		var banner = Kit.new()
		banner.name = "Banner_%s"%x
		banner.position = Vector3(x,0,-7.36)
		add_child(banner)
		banner.banner()
	for z in [-5,0,5]:
		var pillar = Kit.new()
		pillar.name = "WestPilaster_%s"%z
		pillar.position = Vector3(-11.6,0,z)
		add_child(pillar)
		pillar.pillar()
