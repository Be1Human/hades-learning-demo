extends "res://scripts/demo01/arena.gd"
## Integration R01: real traversal, combat, boon and result across three rooms.
const ROOM_TYPES=[preload("res://scripts/environment/tartarus_entry_room.gd"),preload("res://scripts/environment/tartarus_reference_room.gd"),preload("res://scripts/environment/tartarus_colonnade_room.gd")]
const ROOM_NAMES=["冥门前厅","双火池战斗厅","守卫柱廊"]
const BoonMenu=preload("res://scripts/integration/boon_menu.gd")
var room_index:=0
var selected_boon:=-1
var boon_menu:Control
var portal_position:=Vector3.ZERO
var journey_log:Array=[]
var transition_lock:=false
var lighting:Node3D
var world_effect_counts:Dictionary={}
var exit_marker:MeshInstance3D

func _setup_world() -> void:
	super._setup_world()
	remove_child(fx)
	fx.queue_free()
	fx=preload("res://scripts/integration/fx.gd").new()
	fx.name="SharedFX_R03"
	add_child(fx)
	var canvas:Node=hud.get_parent()
	canvas.remove_child(hud)
	hud.queue_free()
	hud=preload("res://scripts/integration/hud.gd").new()
	hud.arena=self
	canvas.add_child(hud)
	var menu_canvas:=CanvasLayer.new()
	menu_canvas.name="BoonLayer"
	menu_canvas.layer=20
	add_child(menu_canvas)
	boon_menu=BoonMenu.new()
	menu_canvas.add_child(boon_menu)
	boon_menu.hide()
	boon_menu.set_process_unhandled_key_input(false)
	boon_menu.boon_selected.connect(choose_boon)
	lighting=preload("res://scripts/environment/tartarus_lighting.gd").new()
	add_child(lighting)
	lighting.configure(self)

func restart() -> void:
	if is_instance_valid(boon_menu):
		boon_menu.hide()
		boon_menu.set_process_unhandled_key_input(false)
		boon_menu.reset_choice()
	selected_boon=-1
	transition_lock=false
	journey_log.clear()
	world_effect_counts.clear()
	super.restart()
	_load_room(0)
	_set_phase("entry")
	hud.notify("走向冥门，按 E 开始试炼")

func _load_room(index:int) -> void:
	player._cancel_charge()
	_clear_enemies()
	fx.clear()
	if is_instance_valid(art):
		remove_child(art)
		art.queue_free()
	room_index=index
	art=ROOM_TYPES[index].new()
	add_child(art)
	art.build()
	nav_obstacles.clear()
	nav_corners.clear()
	for spec in art.layout.pits:
		var r:Array=spec.rect
		nav_obstacles.append(Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1]))
	if index==1:
		nav_obstacles.append(Rect2(.02,.82,1.96,2.38))
		# Reserve pottery and back columns, beyond the open top and side routes.
		nav_obstacles.append(Rect2(-9.4,-4.3,3.1,2.35))
		for x in art.layout.columns:nav_obstacles.append(Rect2(x-.75,-5.0,1.5,1.25))
		player.position=Vector3(-3.3,0,-2.1)
		portal_position=Vector3(9,0,-2.2)
		spawn_points=[Vector3(-7.2,0,5.8),Vector3(7.8,0,-2),Vector3(.6,0,-2),Vector3(8.8,0,6.1)]
		camera_target=Vector3(.5,.4,1.5)
		camera_home=Vector3(-13.5,17.5,15.5)
		camera.size=16.3
	else:
		for p in art.column_layout:nav_obstacles.append(Rect2(p.x-.60,p.z-.60,1.2,1.2))
		for x in [-3.1,3.1]:nav_obstacles.append(Rect2(x-.42,-2.97,.84,.84))
		nav_obstacles.append(Rect2(-6.8,-3.85,3.05,2.45))
		nav_obstacles.append(Rect2(3.25,2.8,3.25,2.3))
		if index==2:
			for x in [-5.8,5.8]:nav_obstacles.append(Rect2(x-.55,.1,1.1,1.4))
		player.position=Vector3(0,0,4.3)
		portal_position=Vector3(0,0,-3.25)
		spawn_points=[Vector3(-1.3,0,-1.2),Vector3(1.3,0,-1.2),Vector3(-1.3,0,2.6),Vector3(1.3,0,2.6)]
		camera_target=Vector3(0,.6,.35)
		camera_home=camera_target+Vector3(-17,20,17)
		camera.size=15.6
	for rect in nav_obstacles:
		var expanded:Rect2=rect.grow(.75)
		for corner in [expanded.position,Vector2(expanded.end.x,expanded.position.y),expanded.end,Vector2(expanded.position.x,expanded.end.y)]:
			var point:=Vector3(corner.x,0,corner.y)
			if point_walkable(point,.64):nav_corners.append(point)
	lighting.room_loaded(art,index)
	exit_marker=MeshInstance3D.new()
	exit_marker.name="ExitMarker"
	var ring:=TorusMesh.new()
	ring.inner_radius=.61
	ring.outer_radius=.67
	ring.rings=48
	ring.ring_segments=8
	exit_marker.mesh=ring
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color("7cbf98")
	mat.emission_enabled=true
	mat.emission=Color("6acb9d")
	mat.emission_energy_multiplier=.6
	exit_marker.material_override=mat
	exit_marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art.add_child(exit_marker)
	exit_marker.position=portal_position+Vector3.UP*.065
	exit_marker.visible=index==0
	camera_offset=Vector3.ZERO
	camera.position=camera_home
	camera.look_at(camera_target)
	player.clear_input()
	player.state="idle"
	player.elapsed=0
	player.dash_iframes=false
	player.visual.set_motion("idle")
	player.aim_direction=Vector3.FORWARD
	journey_log.append({"room":index,"name":ROOM_NAMES[index],"time":run_time,"health":player.health,"boon":selected_boon})
	_world_event("spawn",player.position)
	if index==0:_world_event("exit",portal_position)

func _world_event(kind:String,pos:Vector3) -> void:
	fx.world_event(pos,kind)
	world_effect_counts[kind]=int(world_effect_counts.get(kind,0))+1

func _set_phase(value:String,clock:=0.0) -> void:
	super._set_phase(value,clock)
	if is_instance_valid(exit_marker):exit_marker.visible=value in ["entry","cleared"]
	if is_instance_valid(hud):hud.visible=value!="boon"

func near_portal() -> bool:
	return player.position.distance_to(portal_position)<1.65

func interact() -> void:
	if paused or transition_lock or not near_portal():return
	if phase=="entry":
		transition_lock=true
		audio.play("ui_confirm")
		_load_room(1)
		_set_phase("intro",1.8)
		transition_lock=false
	elif phase=="cleared":open_boon()

func open_boon() -> void:
	if phase!="cleared" or selected_boon>=0:return
	player.clear_input()
	player._cancel_charge()
	player.visual.set_motion("idle")
	_set_phase("boon")
	_freeze_animation(true)
	audio.set_suspended(true)
	audio.play("ui_confirm")
	boon_menu.reset_choice()
	boon_menu.show()
	boon_menu.set_process_unhandled_key_input(true)

func choose_boon(index:int) -> void:
	if phase!="boon" or selected_boon>=0 or index<0 or index>2:return
	selected_boon=index
	match index:
		0:player.damage_multiplier=1.3
		1:
			player.max_health=125
			player.health=minf(125,player.health+25)
		2:player.dash_recharge_multiplier=.75
	player.health=minf(player.max_health,player.health+20)
	boon_menu.hide()
	boon_menu.set_process_unhandled_key_input(false)
	audio.set_suspended(false)
	audio.play("ui_confirm")
	_load_room(2)
	_world_event("heal",player.position)
	_set_phase("intro",1.8)
	hud.notify("获得祝福 · 恢复 20 生命 · 最后一战")
	_freeze_animation(false)

func accepts_actions() -> bool:
	return not paused and phase in ["entry","intro","combat","intermission","cleared"]

func set_paused(value:bool) -> void:
	if phase=="boon":return
	super.set_paused(value)

func _unhandled_input(event:InputEvent) -> void:
	if phase=="boon":return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:
		interact()
		return
	super._unhandled_input(event)

func _start_wave() -> void:
	super._start_wave()
	for enemy in enemies:_world_event("spawn",enemy.position)

func advance(delta:float) -> void:
	if phase=="boon" or transition_lock:return
	if not paused:lighting.tick(delta)
	super.advance(delta)
	if phase=="intermission" and wave==2 and room_index==1:
		_set_phase("cleared")
		_world_event("reward",portal_position)
		_world_event("exit",portal_position)
		hud.notify("战斗厅已清理 · 前往光门领取祝福")

func _ready() -> void:
	super._ready()
	if "--integrated-smoke" in OS.get_cmdline_user_args():_integrated_smoke.call_deferred()

func _integrated_smoke() -> void:
	test_control=true
	# Resource smoke is controlled; full input/menu traversal has a separate replay.
	_load_room(1)
	_start_wave()
	await get_tree().process_frame
	var hero_clips=["idle","run","run_start","run_stop","turn_left","turn_right","slash_1","slash_2","thrust","dash","dash_strike","nova","hurt","death"]
	var enemy_clips=["idle","run","club_attack","hurt","death"]
	var valid:bool=room_index==1 and hero_clips.all(func(clip):return player.visual.animation_names.has(clip)) and enemy_clips.all(func(clip):return enemies[0].visual.animation_names.has(clip)) and boon_menu.textures.size()>=10 and audio.streams.size()==20
	print("INTEGRATED_SMOKE ok=",valid," ui=",boon_menu.textures.size()," audio=",audio.streams.size())
	audio.shutdown()
	get_tree().quit(0 if valid else 1)
