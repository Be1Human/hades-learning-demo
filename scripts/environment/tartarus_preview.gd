extends Node3D
## Independent environment review: does not depend on combat or character work.
const Room = preload("res://scripts/environment/tartarus_reference_room.gd")
var camera: Camera3D
var room: Node3D
var azimuth := -.785398
var elevation := .52
var view_size := 10.4
var camera_focus := Vector3(-1.09,0,-.816)
var dragging := false

func _ready() -> void:
	room = Room.new()
	add_child(room)
	room.build()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("030b0b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("657791")
	env.ambient_light_energy = .12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = .62
	env.glow_bloom = .08
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.17
	env.adjustment_saturation = .97
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	env.ssao_radius = .75
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-62,-45,0)
	key.light_color = Color("d3cdb0")
	key.light_energy = .40
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 45
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-35,140,0)
	rim.light_color = Color("8b79ca")
	rim.light_energy = .36
	add_child(rim)
	# Soft painted bounce pools keep the walkway legible without flooding every surface green.
	for pos in [Vector3(-3,3.5,-2),Vector3(6,3.5,-1.5),Vector3(0,3.5,6.5)]:
		var bounce:=OmniLight3D.new()
		bounce.name="WalkwayBounce"
		bounce.position=pos
		bounce.light_color=Color("d6d6a1")
		bounce.light_energy=1.5
		bounce.omni_range=5.7
		bounce.omni_attenuation=1.8
		add_child(bounce)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 100
	add_child(camera)
	camera.current = true
	_update_camera()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var label := Label.new()
	label.text = "塔尔塔罗斯 · 原版 03 场景复刻\n拖动旋转 · 滚轮缩放 · R 原图机位 · T 俯视"
	label.position = Vector2(24,22)
	label.add_theme_color_override("font_color",Color("dfcca3"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	overlay.add_child(label)
	if "--smoke" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		print("TARTARUS_PREVIEW_OK reference=03 pits=",room.layout.pits.size())
		get_tree().quit()

func _update_camera() -> void:
	camera.size = view_size
	camera.position = Vector3(sin(azimuth)*cos(elevation),sin(elevation),cos(azimuth)*cos(elevation))*32+camera_focus
	camera.look_at(camera_focus)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: view_size = maxf(7,view_size-1)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: view_size = minf(38,view_size+1)
	if event is InputEventMouseMotion and dragging:
		azimuth -= event.relative.x*.006
		elevation = clampf(elevation+event.relative.y*.004,.25,1.55)
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_R:
			azimuth = -.785398
			elevation = .52
			view_size = 10.4
		if event.physical_keycode == KEY_T: elevation = 1.55
	_update_camera()
