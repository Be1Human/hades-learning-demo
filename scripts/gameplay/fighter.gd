extends "res://scripts/demo01/fighter.gd"
## Cast and death-defiance share the playable character's real action clock.
var cast_released:=false

func request(action:String) -> void:
	if action=="cast":
		if dead or not arena.accepts_actions() or state not in ["idle","run"] or arena.bloodstones<=0:return
		_cancel_charge()
		clear_input()
		state="cast"
		elapsed=0
		cast_released=false
		facing=aim_direction.normalized()
		visual.rotation.y=atan2(facing.x,facing.z)
		visual.play("thrust",1.0,.035)
		action_started.emit("cast")
		return
	if state=="cast" and action!="dash":return
	super.request(action)

func tick(delta:float) -> void:
	if state!="cast":
		super.tick(delta)
		return
	# Cast has its own action clock, but still honors the normal dash buffer.
	# Consume a ready request before release; expire unavailable input during
	# windup so it cannot unexpectedly trigger after cast recovery.
	if input_buffer=="dash" and buffer_time>0 and dash_cooldown<=delta:
		_begin_dash()
		super.tick(delta)
		return
	buffer_time=maxf(0,buffer_time-delta)
	if buffer_time<=0:input_buffer=""
	elapsed+=delta
	hurt_invuln=maxf(0,hurt_invuln-delta)
	dash_cooldown=maxf(0,dash_cooldown-delta)
	visual.seek_action("thrust",elapsed*.85)
	if elapsed>=.16 and not cast_released:
		cast_released=true
		arena.cast_stone(global_position+Vector3.UP*1.0,facing)
	if elapsed>=.48:state="idle"

func take_hit(amount:float,direction:=Vector3.ZERO,force:=3.4) -> bool:
	if not dead and arena.accepts_actions() and not dash_iframes and hurt_invuln<=0 and amount>=health and arena.revives>0:
		if super.take_hit(maxf(0,health-.01),direction,force):
			arena.begin_revive()
			return true
		return false
	return super.take_hit(amount,direction,force)
