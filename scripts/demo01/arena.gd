extends Node3D
const Rules=preload("res://scripts/demo01/rules.gd")
const Fighter=preload("res://scripts/demo01/fighter.gd")
const Enemy=preload("res://scripts/demo01/enemy.gd")
const HUD=preload("res://scripts/demo01/hud.gd")
const FX=preload("res://scripts/demo01/fx.gd")
const Room=preload("res://scripts/environment/tartarus_reference_room.gd")
signal phase_changed(value)
var player: CharacterBody3D
var enemies: Array=[]
var camera: Camera3D
var fx: Node3D
var audio: AudioBank
var hud: Control
var art: Node3D
var camera_target:=Vector3(.5,.5,1.5)
var camera_home:=Vector3(-13.5,17.5,15.5)
var camera_offset:=Vector3.ZERO
var phase:="intro"
var phase_clock:=0.0
var wave:=0
var paused:=false
var enemy_ai:=true
var hit_stop:=0.0
var shake_strength:=0.0
var run_time:=0.0
var hit_count:=0
var total_damage:=0.0
var kills:=0
var damage_taken:=0.0
var test_control:=false
var action_log: Array=[]
var hit_log: Array=[]
var phase_log: Array=[]
var fx_counts: Dictionary={}
var fx_log: Array=[]
var spawn_points: Array[Vector3]=[Vector3(-7.6,0,-2),Vector3(7.8,0,-2),Vector3(.6,0,-2),Vector3(8.8,0,6.1)]
var nav_obstacles: Array[Rect2]=[]
var nav_corners: Array[Vector3]=[]

func _ready() -> void:
	_setup_input()
	_setup_world()
	restart()
	if "--demo01-smoke" in OS.get_cmdline_user_args():_smoke_test.call_deferred()

func _smoke_test() -> void:
	test_control=true
	enemy_ai=false
	_start_wave()
	await get_tree().physics_frame
	player.aim_direction=Vector3.RIGHT
	player.request("attack")
	for _i in range(36):await get_tree().physics_frame
	var valid: bool=player.visual.animation_names.size()==10 and enemies[0].visual.animation_names.size()==5 and hud.health_frame!=null
	valid=valid and FileAccess.file_exists("res://assets/characters/demo01/animation-manifest.json")
	valid=valid and player.visual.phase_map.size()==10 and enemies[0].visual.phase_map.size()==5
	print("DEMO01_SMOKE ok=%s hero_clips=%d enemy_clips=%d phase=%s wave=%d effects=%s phase_map=%d/%d"%[str(valid),player.visual.animation_names.size(),enemies[0].visual.animation_names.size(),phase,wave,str(fx_counts.keys()),player.visual.phase_map.size(),enemies[0].visual.phase_map.size()])
	audio.shutdown()
	get_tree().quit(0 if valid else 1)

func _setup_input() -> void:
	for spec in [["demo_move_up",KEY_W],["demo_move_down",KEY_S],["demo_move_left",KEY_A],["demo_move_right",KEY_D],["demo_dash",KEY_SPACE],["demo_special",KEY_Q]]:
		if not InputMap.has_action(spec[0]):InputMap.add_action(spec[0])
		var key:=InputEventKey.new()
		key.physical_keycode=spec[1]
		if not InputMap.action_has_event(spec[0],key):InputMap.action_add_event(spec[0],key)
	for spec in [["demo_attack",MOUSE_BUTTON_LEFT],["demo_special",MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(spec[0]):InputMap.add_action(spec[0])
		var button:=InputEventMouseButton.new()
		button.button_index=spec[1]
		if not InputMap.action_has_event(spec[0],button):InputMap.action_add_event(spec[0],button)

func _setup_world() -> void:
	var environment:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("0a1518")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("8ca6b4")
	env.ambient_light_energy=.30
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.glow_enabled=true
	env.glow_intensity=.5
	environment.environment=env
	add_child(environment)
	var key:=DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-55,-35,0)
	key.light_color=Color("ffe0ad")
	key.light_energy=.80
	key.shadow_enabled=true
	add_child(key)
	var rim:=DirectionalLight3D.new()
	rim.rotation_degrees=Vector3(-35,140,0)
	rim.light_color=Color("82c9bd")
	rim.light_energy=.20
	add_child(rim)
	art=Room.new()
	art.name="TartarusReference05"
	add_child(art)
	art.build()
	# Gameplay knows the two pits and the solid central altar; it does not erase them.
	for spec in art.layout.pits:
		var r: Array=spec.rect
		nav_obstacles.append(Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1]))
	nav_obstacles.append(Rect2(.02,.82,1.96,2.38))
	for rect in nav_obstacles:
		var expanded:=rect.grow(.72)
		for corner in [expanded.position,Vector2(expanded.end.x,expanded.position.y),expanded.end,Vector2(expanded.position.x,expanded.end.y)]:
			var point:=Vector3(corner.x,0,corner.y)
			if point_walkable(point,.64):nav_corners.append(point)
	camera=Camera3D.new()
	camera.name="GameplayCamera"
	add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=15.0
	camera.position=camera_home
	camera.look_at(camera_target)
	camera.current=true
	camera.far=100
	fx=FX.new()
	fx.name="CombatEffects"
	add_child(fx)
	audio=AudioBank.new()
	add_child(audio)
	var canvas:=CanvasLayer.new()
	add_child(canvas)
	hud=HUD.new()
	hud.arena=self
	canvas.add_child(hud)

func restart() -> void:
	paused=false
	if is_instance_valid(audio):
		audio.reset_mix()
		audio.start_ambience()
	if is_instance_valid(fx):fx.clear()
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	_clear_enemies()
	player=Fighter.new()
	player.name="Zagreus"
	add_child(player)
	player.initialize(self)
	player.position=Vector3(-3.3,0,-2.1)
	player.action_started.connect(_action_started)
	player.damaged.connect(func(amount):damage_taken+=amount)
	wave=0
	hit_stop=0
	shake_strength=0
	camera_offset=Vector3.ZERO
	run_time=0
	hit_count=0
	total_damage=0
	kills=0
	damage_taken=0
	action_log.clear()
	hit_log.clear()
	phase_log.clear()
	fx_counts.clear()
	fx_log.clear()
	hud.clear()
	_set_phase("intro",2.0)

func _clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			remove_child(enemy)
			enemy.queue_free()
	enemies.clear()

func _set_phase(value: String,clock:=0.0) -> void:
	phase=value
	phase_clock=clock
	phase_log.append({"phase":phase,"wave":wave,"time":run_time})
	phase_changed.emit(phase)

func _start_wave() -> void:
	_clear_enemies()
	wave+=1
	for i in range(Rules.WAVE_COUNTS[wave-1]):
		var enemy:=Enemy.new()
		enemy.name="Brute_%d_%d"%[wave,i+1]
		add_child(enemy)
		enemy.initialize(self,Rules.ENEMY_HEALTH[wave-1])
		enemy.position=spawn_points[(i+wave-1)%spawn_points.size()]
		enemy.attack_cooldown=.6+i*.22
		enemies.append(enemy)
	_set_phase("combat")
	hud.notify("第 %d 波 · 持棒暴徒"%wave)

func living_enemies() -> int:
	var count:=0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:count+=1
	return count

func accepts_actions() -> bool:
	return not paused and phase in ["intro","combat","intermission"]

func finish(won: bool) -> void:
	if phase in ["victory","defeat"]:return
	_set_phase("victory" if won else "defeat",0.0 if won else 1.35)
	hit_stop=0
	player.clear_input()
	player._cancel_charge()
	if won:
		player.state="idle"
		player.visual.set_motion("idle")
	for enemy in enemies:enemy.cancel_attack()
	audio.stop_cue("charge")
	if won:audio.play("encounter_clear")

func set_paused(value: bool) -> void:
	if phase in ["victory","defeat"]:return
	paused=value
	player.clear_input()
	audio.set_suspended(paused)
	audio.play("ui_pause")
	_freeze_animation(paused)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				set_paused(not paused)
				return
			KEY_R:
				restart()
				audio.play("ui_confirm")
				return
			KEY_F3:
				audio.set_muted(not audio.muted)
				return
	if not accepts_actions():return
	for action in ["attack","dash","special"]:
		if event.is_action_pressed("demo_"+action) and not event.is_echo():
			_update_aim()
			player.request(action)

func _screen_direction(axis: Vector2) -> Vector3:
	var right:=camera.global_basis.x
	var down:=camera.global_basis.z
	right.y=0
	down.y=0
	return (right.normalized()*axis.x+down.normalized()*axis.y).limit_length()

func movement_direction() -> Vector3:
	return player.move_axis if test_control else _screen_direction(Input.get_vector("demo_move_left","demo_move_right","demo_move_up","demo_move_down"))

func _update_aim() -> void:
	if test_control:return
	var screen:=get_viewport().get_mouse_position()
	var point: Variant=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
	if point!=null:
		var offset: Vector3=point-player.global_position
		offset.y=0
		if offset.length()>.15:player.aim_direction=offset.normalized()

func _physics_process(delta: float) -> void:
	advance(delta)

func _freeze_animation(freeze: bool) -> void:
	if is_instance_valid(player) and player.visual.anim:player.visual.anim.speed_scale=0 if freeze else 1
	for enemy in enemies:
		if enemy.visual.anim:enemy.visual.anim.speed_scale=0 if freeze else 1

func advance(delta: float) -> void:
	if not is_instance_valid(player):return
	_freeze_animation(paused or hit_stop>0)
	if paused:return
	fx.tick(delta,hit_stop>0)
	shake_strength=move_toward(shake_strength,0,delta*1.6)
	var follow: Vector3=(player.position-camera_target)*.40
	follow=Vector3(clampf(follow.x,-3,3),0,clampf(follow.z,-2.6,2.6))
	camera_offset=camera_offset.lerp(follow,minf(1,delta*6))
	camera.position=camera_home+camera_offset+Vector3(randf_range(-1,1),randf_range(-.4,.4),randf_range(-1,1))*shake_strength
	camera.look_at(camera_target+camera_offset)
	if phase in ["victory","defeat"]:
		phase_clock=maxf(0,phase_clock-delta)
		for enemy in enemies:
			if enemy.dead:enemy.tick(delta)
		return
	run_time+=delta
	if hit_stop>0:
		hit_stop=maxf(0,hit_stop-delta)
		return
	if not test_control:
		player.move_axis=movement_direction()
		_update_aim()
		if Input.is_action_pressed("demo_attack") and player.state in ["idle","run"]:player.request("attack")
	player.tick(delta)
	for enemy in enemies:
		if phase=="defeat":break
		enemy.tick(delta)
	if phase in ["intro","intermission"]:
		phase_clock=maxf(0,phase_clock-delta)
		if phase_clock<=0:_start_wave()
	elif phase=="combat" and living_enemies()==0:
		if wave>=Rules.WAVE_COUNTS.size():finish(true)
		else:
			player.clear_input()
			_set_phase("intermission",2.8)
			audio.play("encounter_clear")

func _action_started(action: String) -> void:
	hud.last_action=hud.names.get(action,action)
	action_log.append({"time":run_time,"action":action})

func record_fx(id: String,at_position: Variant=null) -> void:
	assert(id in Rules.FX_IDS,"Effect outside first-demo scope: "+id)
	fx_counts[id]=int(fx_counts.get(id,0))+1
	var p: Vector3=player.global_position
	var location: Vector3=p if at_position==null else at_position
	var screen:=camera.unproject_position(location+Vector3.UP*.8)
	var player_screen:=camera.unproject_position(p+Vector3.UP*.8)
	fx_log.append({"id":id,"time":run_time,"wave":wave,"phase":phase,"position":[location.x,location.y,location.z],"screen_position":[screen.x,screen.y],"player_screen_position":[player_screen.x,player_screen.y],"player_position":[p.x,p.y,p.z],"action":player.state,"player_health":player.health})

func confirm_hit(enemy: CharacterBody3D,amount: float,data: Dictionary,result: Dictionary) -> void:
	if result.get("ignored",false):return
	hit_count+=1
	total_damage+=amount
	hit_stop=maxf(hit_stop,float(data.stop))
	shake_strength=maxf(shake_strength,float(data.shake))
	if result.killed:kills+=1
	fx.impact(enemy.global_position,player.facing,false,false,false)
	record_fx("hit",enemy.global_position)
	hud.damage_number(enemy.global_position,amount)
	audio.play("impact")
	hit_log.append({"time":run_time,"wave":wave,"action":player.state,"enemy":enemy.name,"damage":amount,"killed":result.killed})

func point_walkable(point: Vector3,radius: float) -> bool:
	var b: Array=art.layout.bounds
	if point.x<float(b[0])+radius or point.x>float(b[2])-radius or point.z<float(b[1])+radius or point.z>float(b[3])-radius:return false
	for rect in nav_obstacles:
		if rect.grow(radius).has_point(Vector2(point.x,point.z)):return false
	return true

func constrain_actor(point: Vector3,radius: float,previous: Vector3) -> Vector3:
	var b: Array=art.layout.bounds
	point.y=0
	point.x=clampf(point.x,b[0]+radius+.08,b[2]-radius-.08)
	point.z=clampf(point.z,b[1]+radius+.08,b[3]-radius-.08)
	if point_walkable(point,radius):return point
	# Collision normally stops the move first. This guard prevents tunnelling into pits.
	return Vector3(previous.x,0,previous.z)

func _clear_segment(a: Vector3,b: Vector3,margin: float) -> bool:
	var length:=a.distance_to(b)
	var steps:=maxi(1,ceili(length/.18))
	for i in range(steps+1):
		var point:=a.lerp(b,float(i)/steps)
		for rect in nav_obstacles:
			if rect.grow(margin).has_point(Vector2(point.x,point.z)):return false
	return true

func has_combat_line(a: Vector3,b: Vector3) -> bool:
	return _clear_segment(a,b,0)

func _navigation_point(point: Vector3,margin: float) -> Vector3:
	# Knockback can leave an actor closer to a rim than the preferred navigation
	# clearance. First steer it out of that band instead of returning no path.
	for _pass in range(4):
		for obstacle in nav_obstacles:
			var rect:=obstacle.grow(margin+.015)
			var p:=Vector2(point.x,point.z)
			if not rect.has_point(p):continue
			var options: Array[Vector2]=[Vector2(rect.position.x-.005,p.y),Vector2(rect.end.x+.005,p.y),Vector2(p.x,rect.position.y-.005),Vector2(p.x,rect.end.y+.005)]
			var nearest:=options[0]
			for option in options:
				if p.distance_squared_to(option)<p.distance_squared_to(nearest):nearest=option
			point=Vector3(nearest.x,0,nearest.y)
	return point

func chase_waypoint(origin: Vector3,target: Vector3,margin: float) -> Vector3:
	var clear_origin:=_navigation_point(origin,margin)
	if clear_origin.distance_to(origin)>.025:return clear_origin
	target=_navigation_point(target,margin)
	if _clear_segment(origin,target,margin):return target
	var points: Array[Vector3]=[origin,target]
	points.append_array(nav_corners)
	var distances: Array[float]=[]
	var previous: Array[int]=[]
	var visited: Array[bool]=[]
	for i in range(points.size()):
		distances.append(INF)
		previous.append(-1)
		visited.append(false)
	distances[0]=0
	for _step in range(points.size()):
		var best:=-1
		for i in range(points.size()):
			if not visited[i] and (best<0 or distances[i]<distances[best]):best=i
		if best<0 or is_inf(distances[best]):break
		if best==1:break
		visited[best]=true
		for i in range(points.size()):
			if visited[i] or not _clear_segment(points[best],points[i],margin):continue
			var candidate:=distances[best]+points[best].distance_to(points[i])
			if candidate<distances[i]:
				distances[i]=candidate
				previous[i]=best
	if previous[1]<0:return origin
	var next:=1
	while previous[next]>0:next=previous[next]
	return points[next]
