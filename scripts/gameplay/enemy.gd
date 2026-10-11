extends "res://scripts/demo01/enemy.gd"
## Uses the existing authored rig. New enemy roles own actual AI and attack clocks.
var kind:="brute"
var move:=""
var move_index:=0
var locked_position:=Vector3.ZERO
var rush_start:=Vector3.ZERO
var wall_armed:=false
var blast_marks:Array=[]
var blast_fired:=0
var rush_distance:=0.0
var rush_effects:Array=[]

func initialize(owner_arena:Node3D,hp:=100.0) -> void:
	super.initialize(owner_arena,hp)
	if kind=="boss":visual.scale*=1.35;radius=.68
	if kind in ["witch","skull"] and is_instance_valid(visual.weapon):visual.weapon.hide()
	if kind=="witch":visual.scale=Vector3(.8,1.10,.8)
	if kind=="skull":
		visual.model.hide()
		_make_skull()
	if kind in ["witch","boss"]:
		for mesh in visual.meshes:
			for surface in range(mesh.mesh.get_surface_count()):
				var material=mesh.get_surface_override_material(surface)
				if material is ShaderMaterial:
					material=material.duplicate();material.set_shader_parameter("base_tint",Color("c7a4e0") if kind=="witch" else Color("ca87a9"));mesh.set_surface_override_material(surface,material)
	var title:=Label3D.new();title.text={"brute":"暴徒","witch":"女巫","skull":"骷髅","boss":"冥界监军"}[kind]
	title.position.y=3.15 if kind=="boss" else 2.85;title.font_size=35;title.pixel_size=.006;title.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title)

func _make_skull() -> void:
	var bone:=StandardMaterial3D.new();bone.albedo_color=Color("c9b78e");bone.roughness=.8
	var dark:=StandardMaterial3D.new();dark.albedo_color=Color("271e2a")
	var glow:=StandardMaterial3D.new();glow.albedo_color=Color("ff7942");glow.emission_enabled=true;glow.emission=Color("ff4f21")
	for spec in [[Vector3(0,1.35,0),Vector3(.85,.8,.75),bone],[Vector3(-.21,1.38,.31),Vector3(.25,.27,.16),dark],[Vector3(.21,1.38,.31),Vector3(.25,.27,.16),dark],[Vector3(-.21,1.38,.39),Vector3(.09,.1,.07),glow],[Vector3(.21,1.38,.39),Vector3(.09,.1,.07),glow],[Vector3(0,1.03,.16),Vector3(.6,.22,.45),bone]]:
		var part:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.5;sphere.height=1
		part.mesh=sphere;part.position=spec[0];part.scale=spec[1];part.material_override=spec[2];visual.add_child(part)

func start_move(next_move:String="") -> void:
	if dead:return
	cancel_attack();state="attack";clock=0;attack_applied=false
	facing=(arena.player.position-position).normalized();facing.y=0
	if facing.is_zero_approx():facing=Vector3.FORWARD
	visual.rotation.y=atan2(facing.x,facing.z)
	locked_position=arena.player.position;rush_start=position
	move=next_move if next_move!="" else (["whip","rush","barrage","blast"][move_index%4] if kind=="boss" else kind)
	move_index+=1
	rush_distance=6.0 if kind=="boss" else 3.6
	if move in ["rush","skull"]:
		for step in range(1,61):
			var distance:float=step*.10
			if distance>rush_distance:break
			if not arena.point_walkable(position+facing*distance,radius):rush_distance=maxf(.1,distance-.1);break
	visual.play("club_attack",1.0,.06)
	var id:="witch_cast" if kind=="witch" else "skull_warning" if kind=="skull" else "boss_warning_"+move
	if kind=="boss" and move=="blast":
		blast_marks=[locked_position];blast_fired=0
		for ray in [Vector3(1.8,0,0),Vector3(-1.8,0,0)]:
			var p:Vector3=locked_position+ray
			if arena.point_walkable(p,.1):blast_marks.append(p)
		for i in range(blast_marks.size()):
			arena.router.emit_event(id,{"position":blast_marks[i],"direction":facing,"duration":.8+i*.22,"owner":self,"channel":"blast"+str(i)})
			arena.record_event(id,blast_marks[i],self,{"radius":1.7,"delay":.8+i*.22})
	else:
		telegraph=arena.router.emit_event(id,{"position":position,"direction":facing,"duration":.62 if kind=="witch" else .55 if kind=="skull" else .8,"owner":self,"channel":"windup"})
		if move in ["rush","skull"]:telegraph.scale.z=rush_distance/(6.0 if kind=="boss" else 3.6)
		arena.record_event(id,position,self,{"locked_direction":[facing.x,0,facing.z]})

func cancel_attack() -> void:
	for node in rush_effects:arena.fx.cancel(node)
	rush_effects.clear()
	if is_instance_valid(arena) and arena.router:arena.router.cancel_owner(self)
	blast_marks.clear()
	super.cancel_attack()

func tick(delta:float) -> void:
	if kind=="brute":
		var before:=position;var force:float=push_velocity.length()
		super.tick(delta)
		_check_wall(before,force)
		return
	if dead:super.tick(delta);return
	clock+=delta;attack_cooldown-=delta
	flash_left=maxf(0,flash_left-delta);visual.flash(flash_left)
	var before:=position;var force:float=push_velocity.length()
	velocity=push_velocity;push_velocity=push_velocity.move_toward(Vector3.ZERO,delta*17)
	if state=="hurt":
		if clock>.28:state="idle"
	elif state=="attack":
		var windup:float=.62 if kind=="witch" else .55 if kind=="skull" else .8
		visual.seek_action("club_attack",clock*.62/windup)
		if clock>=windup and not attack_applied:
			attack_applied=true
			arena.fx.cancel(telegraph);telegraph=null
			_release()
		if attack_applied and move in ["rush","skull"]:
			var distance:float=rush_distance
			var duration:float=.38 if kind=="boss" else .28
			var desired:Vector3=rush_start+facing*minf(distance,(clock-windup)*distance/duration)
			var constrained:Vector3=arena.constrain_actor(desired,radius,position)
			var contact:bool=arena.player.position.distance_to(constrained)<radius+.45
			if constrained.distance_to(desired)>.02 or contact or clock>=windup+duration:
				if contact:arena.player.take_hit(20 if kind=="boss" else 12,facing)
				if kind=="skull":arena.fx.skull_impact(position,facing);arena.record_event("skull_impact",position,self,{"contact":contact})
				for node in rush_effects:arena.fx.cancel(node)
				rush_effects.clear()
				state="recover";clock=0
			else:position=constrained
		elif attack_applied and move=="blast":
			while blast_fired<blast_marks.size() and clock>=.8+blast_fired*.22:
				var at:Vector3=blast_marks[blast_fired];blast_fired+=1
				arena.fx.boss(at,facing,"blast");arena.record_event("boss_blast",at,self,{"radius":1.7})
				if arena.player.position.distance_to(at)<1.7+.34 and arena.has_combat_line(at,arena.player.position):arena.player.take_hit(18,facing)
		if state=="attack" and clock>windup+.75:state="recover";clock=0
	elif state=="recover":
		if clock>.7:state="idle";attack_cooldown=.7
	elif arena.enemy_ai and arena.phase=="combat" and not arena.player.dead:
		var to_player:Vector3=arena.player.position-position
		var reach:float=7 if kind in ["witch","boss"] else 4.5
		if to_player.length()<reach and arena.has_combat_line(position,arena.player.position) and attack_cooldown<=0:start_move()
		else:
			var waypoint:Vector3=arena.chase_waypoint(position,arena.player.position,radius+.1)
			if to_player.length()>reach*.7:
				facing=(waypoint-position).normalized();velocity+=facing*1.9
				visual.rotation.y=atan2(facing.x,facing.z);visual.set_motion("run")
			else:visual.set_motion("idle")
	if kind=="skull":visual.position.y=sin(clock*4)*.10
	move_and_slide();position=arena.constrain_actor(position,radius,before)
	_check_wall(before,force)

func _release() -> void:
	var first:int=arena.fx.effects.size()
	match move:
		"witch":arena.shoot(position+Vector3.UP,facing,self)
		"skull":arena.fx.skull_rush(position,facing);arena.record_event("skull_rush",position,self,{"distance":3.6})
		"whip":
			arena.fx.boss(position,facing,move);arena.record_event("boss_whip",position,self,{"radius":3.8})
			if arena.player.position.distance_to(position)<3.8+.34 and arena.has_combat_line(position,arena.player.position):arena.player.take_hit(20,facing)
		"rush":arena.fx.boss(position,facing,move);arena.record_event("boss_rush",position,self,{"distance":6.0})
		"barrage":
			# One projectile set supplies both the visible fan and collision; no duplicate fake fan.
			for i in range(7):arena.shoot(position+Vector3.UP,facing.rotated(Vector3.UP,(i-3)*.19),self,6.0)
			arena.record_event("boss_barrage",position,self,{"projectiles":7})
	if move in ["rush","skull"]:
		var full:float=6.0 if kind=="boss" else 3.6
		var direction_basis:=Basis(Vector3.UP,atan2(facing.x,facing.z))
		var shrink:Basis=direction_basis*Basis.from_scale(Vector3(1,1,rush_distance/full))*direction_basis.inverse()
		for effect in arena.fx.effects.slice(first):
			var node:Node3D=effect.node
			if node.get_parent()==arena.fx:
				node.global_transform=Transform3D(shrink,position-shrink*position)*node.global_transform
				if effect.has("start"):
					effect.start=position+shrink*(effect.start-position)
					effect.end=position+shrink*(effect.end-position)
				rush_effects.append(node)

func _check_wall(before:Vector3,force:float) -> void:
	if not wall_armed or dead:return
	if force<.5:wall_armed=false;return
	if force>2 and position.distance_to(before)<.012:
		wall_armed=false
		arena.fx.wall_hit(position,-push_velocity.normalized())
		arena.record_event("wall",position,self,{"damage":22})
		arena.damage_enemy(self,22,-push_velocity.normalized(),0,"wall")

func take_hit(amount:float,direction:Vector3,force:float,action:String) -> Dictionary:
	# Boss telegraphs remain committed; ordinary enemies can be interrupted.
	if kind=="boss" and not dead and health>amount:
		health-=amount;hits_received+=1;flash_left=.075
		return {"killed":false,"ignored":false}
	var old_state:=state;var old_clock:=clock;var old_move:=move
	var result:Dictionary=super.take_hit(amount,direction,force*.25 if kind=="boss" else force,action)
	if kind=="boss" and not dead and old_state=="attack":
		state=old_state;clock=old_clock;move=old_move
	else:
		arena.router.cancel_owner(self);blast_marks.clear()
		for node in rush_effects:arena.fx.cancel(node)
		rush_effects.clear()
	return result
