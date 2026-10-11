extends CharacterBody3D
const Visual=preload("res://scripts/demo01/visual.gd")
var arena: Node3D
var visual: ActorVisual
var radius:=.50
var health:=100.0
var max_health:=100.0
var dead:=false
var facing:=Vector3.BACK
var state:="idle"
var clock:=0.0
var flash_left:=0.0
var push_velocity:=Vector3.ZERO
var attack_applied:=false
var death_clock:=0.0
var death_scale:=Vector3.ONE*1.08
var attack_cooldown:=.7
var telegraph: Node3D
var hits_received:=0
var path_clock:=0.0
var waypoint:=Vector3.ZERO

func initialize(owner_arena: Node3D,hp:=100.0) -> void:
	arena=owner_arena
	health=hp
	max_health=hp
	collision_layer=4
	collision_mask=1
	var col:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=radius
	capsule.height=2.4
	col.shape=capsule
	col.position.y=1.2
	add_child(col)
	visual=Visual.new()
	add_child(visual)
	visual.configure("res://assets/characters/demo01/enemy.glb",true)
	visual.scale=Vector3.ONE*1.08

func cancel_attack() -> void:
	arena.fx.cancel(telegraph)
	telegraph=null
	if not dead:
		state="idle"
		clock=0
		attack_cooldown=.8
		visual.set_motion("idle")
	velocity=Vector3.ZERO

func tick(delta: float) -> void:
	if dead:
		death_clock+=delta
		if death_clock>.30:
			# Keep the final transform invertible while the last sub-pixel shape fades.
			visual.scale=death_scale*maxf(.001,1.0-smoothstep(.30,.60,death_clock))
		if death_clock>=.65:visual.visible=false
		return
	clock+=delta
	flash_left=maxf(0,flash_left-delta)
	visual.flash(flash_left)
	attack_cooldown-=delta
	velocity=push_velocity
	push_velocity=push_velocity.move_toward(Vector3.ZERO,delta*17)
	var to_player: Vector3=arena.player.global_position-global_position
	to_player.y=0
	if state=="hurt":
		if clock>.28:state="idle"
	elif state=="attack":
		visual.seek_action("club_attack",clock)
		if clock>=.62 and not attack_applied:
			attack_applied=true
			arena.fx.cancel(telegraph)
			telegraph=null
			arena.fx.enemy_swing(global_position,facing)
			arena.record_fx("enemy_swing",global_position)
			arena.audio.play("enemy_swing")
			if to_player.length()<2.45 and to_player.normalized().dot(facing)>.25 and arena.has_combat_line(global_position,arena.player.global_position):
				arena.player.take_hit(12,to_player.normalized(),3.4)
		if clock>1.22:
			state="idle"
			attack_cooldown=.95
	elif arena.enemy_ai and not arena.player.dead and arena.phase=="combat":
		path_clock-=delta
		if to_player.length()>2.05 or not arena.has_combat_line(global_position,arena.player.global_position):
			if path_clock<=0 or position.distance_to(waypoint)<.25:
				path_clock=.3
				waypoint=arena.chase_waypoint(position,arena.player.position,radius+.14)
			var direction: Vector3=waypoint-position
			direction.y=0
			if direction.length()>.025:
				facing=direction.normalized()
				velocity+=facing*2.1
				state="run"
				visual.set_motion("run",.85)
			else:
				state="idle"
				visual.set_motion("idle")
		elif attack_cooldown<=0:
			state="attack"
			clock=0
			facing=to_player.normalized()
			visual.rotation.y=atan2(facing.x,facing.z)
			attack_applied=false
			visual.play("club_attack",1.0,.06)
			arena.audio.play("enemy_windup")
			telegraph=arena.fx.warning(global_position,2.45,.64,facing,2*acos(.25),self)
			arena.record_fx("warning",global_position)
		else:
			state="idle"
			visual.set_motion("idle")
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(facing.x,facing.z),minf(1,delta*9))
	else:
		state="idle"
		visual.set_motion("idle")
	for other in arena.enemies:
		if other==self or not is_instance_valid(other) or other.dead:continue
		var away: Vector3=global_position-other.global_position
		away.y=0
		if away.length()<1.12 and away.length()>.01:velocity+=away.normalized()*(1.12-away.length())*3
	var before:=position
	move_and_slide()
	position=arena.constrain_actor(position,radius,before)

func take_hit(amount: float,direction: Vector3,force: float,action: String) -> Dictionary:
	if dead:return {"killed":false,"ignored":true}
	hits_received+=1
	health=maxf(0,health-amount)
	flash_left=.075
	var recoil:=direction
	recoil.y=0
	if not recoil.is_zero_approx():
		recoil=recoil.normalized()
		push_velocity+=recoil*force
		facing=-recoil
		visual.rotation.y=atan2(facing.x,facing.z)
	state="hurt"
	clock=0
	attack_cooldown=maxf(attack_cooldown,.4)
	arena.fx.cancel(telegraph)
	telegraph=null
	visual.play("hurt",1.2 if action!="nova" else .8,.015)
	if health<=0:
		dead=true
		state="death"
		collision_layer=0
		push_velocity=Vector3.ZERO
		death_scale=visual.scale
		visual.play("death",2.5,.04)
		arena.fx.death(global_position)
		arena.record_fx("death",global_position)
		arena.audio.play("death")
	return {"killed":dead,"ignored":false}
