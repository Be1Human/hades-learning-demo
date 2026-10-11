extends RefCounted
## Swept gameplay collision is authoritative; visual interpolation follows this same path.
var game:Node3D
var position:Vector3
var direction:Vector3
var speed:=7.0
var distance_left:=12.0
var damage:=12.0
var hostile:=true
var stone:=false
var alive:=true
var visual:Node3D
var caster:Node3D

func start(world:Node3D,origin:Vector3,ray:Vector3,owner_actor:Node3D,is_stone:=false) -> void:
	game=world;position=origin;direction=ray.normalized();caster=owner_actor;stone=is_stone
	hostile=not stone
	speed=12.0 if stone else 7.0
	damage=38 if stone else 12
	visual=game.fx.projectile(origin,origin+direction*distance_left,distance_left/speed,hostile)
	game.record_event("stone_cast" if stone else "projectile",position,caster,{"damage":damage,"speed":speed})

func tick(delta:float) -> void:
	if not alive:return
	var before:=position
	var step:=minf(distance_left,speed*delta)
	# Subdivide even long frames, so a bullet cannot tunnel through a wall or actor.
	var count:=maxi(1,ceili(step/.10))
	for i in range(1,count+1):
		position=before+direction*step*float(i)/count
		if not game.point_walkable(Vector3(position.x,0,position.z),.10):
			impact(null);return
		if hostile:
			var p:Vector3=game.player.position+Vector3.UP
			var towards:Vector3=position-p;towards.y=0
			if game.ward_remaining>0 and p.distance_to(position)<game.ward_radius and (game.ward_full_circle or towards.normalized().dot(game.ward_direction)>.20):
				reflect();return
			if p.distance_to(position)<.52:
				if game.player.take_hit(damage,direction):impact(game.player);return
		else:
			for enemy in game.enemies:
				if not enemy.dead and (enemy.position+Vector3.UP).distance_to(position)<enemy.radius+.22:
					game.damage_enemy(enemy,damage,direction,2.5,"cast" if stone else "reflect")
					impact(enemy);return
	distance_left-=step
	if is_instance_valid(visual):visual.global_position=position
	if distance_left<=0:impact(null)

func reflect() -> void:
	hostile=false
	game.fx.cancel(visual)
	var target:Vector3=position-direction*10
	if is_instance_valid(caster) and not caster.dead:target=caster.position+Vector3.UP
	direction=(target-position).normalized()
	distance_left=maxf(1,position.distance_to(target)+1)
	speed=11;damage=28
	visual=game.fx.reflected_projectile(position,position+direction*distance_left,distance_left/speed)
	game.record_event("reflected_projectile",position,game.player,{"damage":damage})

func impact(target:Node3D) -> void:
	if not alive:return
	alive=false
	game.fx.cancel(visual)
	if stone:
		if is_instance_valid(target) and target!=game.player and not target.dead:game.embed_stone(target)
		else:game.drop_stone(position)
	else:
		game.fx.witch_impact(position,direction)
		game.record_event("witch_impact",position,caster,{"hit_actor":is_instance_valid(target),"hostile":hostile})
