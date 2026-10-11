extends CharacterBody3D
const Rules=preload("res://scripts/demo01/rules.gd")
const Visual=preload("res://scripts/demo01/visual.gd")
signal action_started(action)
signal locomotion_started(action)
signal landed_hit(target,data)
signal damaged(amount)
var arena: Node3D
var visual: ActorVisual
var state:="idle"
var elapsed:=0.0
var health:=100.0
var max_health:=100.0
var dead:=false
var facing:=Vector3.FORWARD
var aim_direction:=Vector3.FORWARD
var move_axis:=Vector3.ZERO
var input_buffer:=""
var buffer_time:=0.0
var combo:=0
var combo_idle:=0.0
var dash_cooldown:=0.0
var dash_iframes:=false
var hurt_invuln:=0.0
var flash_left:=0.0
var hit_targets: Dictionary={}
var effect_spawned:=false
var charge_fx: Node3D
var distance_travelled:=0.0
var auto_control:=false
var footstep_clock:=0.0
var damage_multiplier:=1.0
var dash_recharge_multiplier:=1.0
var push_velocity:=Vector3.ZERO
var locomotion_clip:=""
var locomotion_clock:=0.0
var locomotion_duration:=0.0
var locomotion_moving:=false
var locomotion_from_yaw:=0.0

func initialize(owner_arena: Node3D) -> void:
	arena=owner_arena
	collision_layer=2
	collision_mask=1
	var col:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.34
	capsule.height=1.9
	col.shape=capsule
	col.position.y=.95
	add_child(col)
	visual=Visual.new()
	add_child(visual)
	visual.configure("res://assets/characters/demo01/hero.glb")

func clear_input() -> void:
	input_buffer=""
	buffer_time=0
	move_axis=Vector3.ZERO
	velocity=Vector3.ZERO
	push_velocity=Vector3.ZERO
	_reset_locomotion()

func request(action: String) -> void:
	if dead or not arena.accepts_actions():return
	if action=="dash" and dash_cooldown<=0:
		# Airborne special is committed until impact; held buffer survives its last frames.
		if state!="nova" or elapsed>=float(Rules.ACTIONS.nova.windup+Rules.ACTIONS.nova.active):
			_begin_dash()
			return
	if action=="attack" and state=="dash":
		_start_attack("dash_strike")
		return
	if action not in ["attack","special","dash"]:return
	input_buffer=action
	buffer_time=Rules.INPUT_BUFFER
	# Keep one deliberate early click until this swing can chain. Repeated clicks
	# replace that slot; they never queue an entire combo behind the player's back.
	if action=="attack" and state in ["slash_1","slash_2","thrust","dash_strike"]:
		var d: Dictionary=Rules.ACTIONS[state]
		buffer_time=maxf(buffer_time,float(d.windup+d.active)+.045-elapsed+Rules.INPUT_BUFFER)
	_consume_input()

func _consume_input() -> void:
	if buffer_time<=0:return
	var available:=state in ["idle","run"]
	if Rules.ACTIONS.has(state):
		var d: Dictionary=Rules.ACTIONS[state]
		available=elapsed>=float(d.windup+d.active)+.045
	if not available:return
	var action:=input_buffer
	if action=="dash" and dash_cooldown>0:return
	input_buffer=""
	buffer_time=0
	match action:
		"attack":
			_start_attack(["slash_1","slash_2","thrust"][combo])
			combo=(combo+1)%3
		"special":_start_attack("nova")
		"dash":_begin_dash()

func _cancel_charge() -> void:
	arena.fx.cancel(charge_fx)
	charge_fx=null
	arena.audio.stop_cue("charge")

func _start_attack(action: String) -> void:
	_cancel_charge()
	_reset_locomotion()
	push_velocity=Vector3.ZERO
	input_buffer=""
	buffer_time=0
	state=action
	if action in ["dash_strike","nova"]:combo=0
	elapsed=0
	combo_idle=0
	effect_spawned=false
	hit_targets.clear()
	dash_iframes=false
	facing=aim_direction.normalized() if not aim_direction.is_zero_approx() else facing
	visual.rotation.y=atan2(facing.x,facing.z)
	visual.play(action,1.0,.035)
	action_started.emit(action)
	if action=="nova":
		charge_fx=arena.fx.charge(global_position,Color("ffd5a0"))
		arena.record_fx("charge")
		arena.audio.play("charge")

func _begin_dash() -> void:
	var axis: Vector3=move_axis
	_cancel_charge()
	clear_input()
	move_axis=axis
	state="dash"
	elapsed=0
	dash_cooldown=Rules.DASH_RECHARGE*dash_recharge_multiplier
	dash_iframes=true
	hit_targets.clear()
	facing=axis.normalized() if axis.length()>.1 else aim_direction.normalized()
	if facing.is_zero_approx():facing=Vector3.FORWARD
	visual.rotation.y=atan2(facing.x,facing.z)
	visual.play("dash",1.0,.02)
	arena.audio.play("dash")
	arena.fx.dash_burst(global_position,facing)
	arena.record_fx("dash")
	action_started.emit("dash")

func tick(delta: float) -> void:
	if dead:return
	dash_cooldown=maxf(0,dash_cooldown-delta)
	hurt_invuln=maxf(0,hurt_invuln-delta)
	flash_left=maxf(0,flash_left-delta)
	visual.flash(flash_left)
	var previous:=elapsed
	elapsed+=delta
	_sample_held_attack()
	_consume_input()
	buffer_time=maxf(0,buffer_time-delta)
	if buffer_time<=0:input_buffer=""
	if elapsed<previous:previous=0
	velocity=Vector3.ZERO
	if Rules.ACTIONS.has(state):_tick_attack(delta,previous)
	elif state=="dash":
		velocity=facing*Rules.DASH_SPEED
		dash_iframes=elapsed<Rules.DASH_INVULNERABLE
		if int(elapsed/.04)!=int(previous/.04):arena.fx.afterimage(visual,Color(.58,.88,.95,.25))
		if elapsed>=Rules.DASH_DURATION:
			state="idle"
			dash_iframes=false
	elif state=="hurt":
		velocity=push_velocity
		push_velocity=push_velocity.move_toward(Vector3.ZERO,delta*18)
		if elapsed>.26:
			state="idle"
			push_velocity=Vector3.ZERO
	else:
		combo_idle+=delta
		if combo_idle>Rules.COMBO_RESET:combo=0
		_tick_locomotion(delta)
	var before:=position
	move_and_slide()
	position=arena.constrain_actor(position,.34,before)
	distance_travelled+=position.distance_to(before)

func _sample_held_attack() -> void:
	# The arena also dispatches press events, but its held-button path only covers
	# idle/run. Sample here so holding attack through a dash has the same result
	# as pressing attack during that dash. Scripted controllers remain explicit.
	if arena.test_control or not arena.accepts_actions() or not Input.is_action_pressed("demo_attack"):return
	if state=="dash":
		if elapsed>=.035:request("attack")
	elif input_buffer=="":
		if state in ["idle","run"]:request("attack")
		elif state in ["slash_1","slash_2","thrust","dash_strike"]:
			var d: Dictionary=Rules.ACTIONS[state]
			# A brief click must remain one swing. Only a button still held at
			# the connection window repeats; an explicit early press uses the buffer.
			if elapsed>=float(d.windup+d.active)+.045:request("attack")

func _reset_locomotion() -> void:
	locomotion_clip=""
	locomotion_clock=0
	locomotion_duration=0
	locomotion_moving=false

func _begin_locomotion(clip_name: String) -> void:
	if not visual.anim or not visual.animation_names.has(clip_name):
		locomotion_clip=""
		return
	locomotion_clip=clip_name
	locomotion_clock=0
	locomotion_duration=visual.anim.get_animation(visual.animation_names[clip_name]).length
	locomotion_from_yaw=visual.rotation.y
	visual.play(clip_name,1.0,.025)
	locomotion_started.emit(clip_name)

func _tick_locomotion(delta: float) -> void:
	var moving:=move_axis.length()>.1
	var target:=move_axis.normalized() if moving else aim_direction.normalized()
	if target.is_zero_approx():target=facing
	var turning:=facing.dot(target)<cos(deg_to_rad(75.0))
	if moving and not locomotion_moving:
		_begin_locomotion("run_start")
	elif not moving and locomotion_moving:
		_begin_locomotion("run_stop")
	elif turning and locomotion_clip not in ["run_start","run_stop"]:
		_begin_locomotion("turn_left" if facing.signed_angle_to(target,Vector3.UP)>0 else "turn_right")
	locomotion_moving=moving
	# Finish the planted stopping pose along the run direction; a different
	# mouse aim can trigger a separate turn once both feet have settled.
	if locomotion_clip=="run_stop":target=facing
	facing=target
	var target_yaw:=atan2(facing.x,facing.z)
	if locomotion_clip in ["turn_left","turn_right"]:
		visual.rotation.y=lerp_angle(locomotion_from_yaw,target_yaw,smoothstep(0,locomotion_duration,locomotion_clock+delta))
	else:visual.rotation.y=lerp_angle(visual.rotation.y,target_yaw,minf(1,delta*18))
	state="run" if moving else "idle"
	velocity=move_axis.limit_length()*Rules.RUN_SPEED if moving else Vector3.ZERO
	if locomotion_clip!="":
		locomotion_clock+=delta
		visual.seek_action(locomotion_clip,locomotion_clock)
		if locomotion_clock>=locomotion_duration:locomotion_clip=""
	if locomotion_clip=="":visual.set_motion("run" if moving else "idle",1.0)
	if moving:
		footstep_clock+=delta
		if footstep_clock>.23:
			footstep_clock=0
			arena.audio.play("step")
	else:footstep_clock=0

func _tick_attack(_delta: float,previous: float) -> void:
	visual.seek_action(state,elapsed)
	var d: Dictionary=Rules.ACTIONS[state]
	var start:=float(d.windup)
	var end:=start+float(d.active)
	# Segment overlap protects the active window against long simulation steps.
	if elapsed>=start and previous<end:
		velocity=facing*float(d.lunge)/float(d.active)
		if not effect_spawned:
			effect_spawned=true
			arena.fx.attack(global_position,facing,state)
			arena.record_fx(state)
			if state=="nova":_cancel_charge()
			arena.audio.play(state if state!="dash_strike" else "thrust")
		for enemy in arena.enemies:
			if not is_instance_valid(enemy) or enemy.dead or hit_targets.has(enemy.get_instance_id()):continue
			if Rules.in_attack(state,global_position,facing,enemy.global_position,enemy.radius) and arena.has_combat_line(global_position,enemy.global_position):
				hit_targets[enemy.get_instance_id()]=true
				var direction: Vector3=(enemy.global_position-global_position).normalized() if state=="nova" else facing
				var damage:float=float(d.damage)*damage_multiplier
				var result: Dictionary=enemy.take_hit(damage,direction,float(d.push),state)
				arena.confirm_hit(enemy,damage,d,result)
				landed_hit.emit(enemy,{"action":state,"damage":damage})
	if state=="nova":velocity=Vector3.ZERO
	if elapsed>=Rules.duration(state):
		state="idle"
		elapsed=0

func take_hit(amount: float,direction:=Vector3.ZERO,force:=3.4) -> bool:
	if dead or not arena.accepts_actions() or dash_iframes or hurt_invuln>0:return false
	var applied:=minf(health,amount)
	health=maxf(0,health-amount)
	_cancel_charge()
	clear_input()
	var recoil: Vector3=direction
	recoil.y=0
	if recoil.is_zero_approx():recoil=-facing
	push_velocity=recoil.normalized()*force
	facing=-recoil.normalized()
	visual.rotation.y=atan2(facing.x,facing.z)
	arena.fx.hurt(global_position,health<=0)
	arena.record_fx("player_death" if health<=0 else "hurt")
	hurt_invuln=.62
	flash_left=.09
	state="hurt"
	elapsed=0
	combo=0
	visual.play("hurt",1.0,.025)
	arena.audio.play("hurt" if health>0 else "player_death")
	arena.hit_stop=maxf(arena.hit_stop,.07)
	arena.shake_strength=.23
	damaged.emit(applied)
	if health<=0:
		dead=true
		push_velocity=Vector3.ZERO
		state="death"
		collision_layer=0
		visual.play("death",1.0,.06)
		arena.finish(false)
	return true
