extends "res://scripts/integration/campaign.gd"
## R06: the default run uses gameplay-owned effects, collisions and resources.
const ExpandedFighter=preload("res://scripts/gameplay/fighter.gd")
const ExpandedEnemy=preload("res://scripts/gameplay/enemy.gd")
const Missile=preload("res://scripts/gameplay/missile.gd")
const FAMILIES=["lightning","deflect","tide"]
var router:CombatFXEvents
var family:="lightning"
var bloodstones:=3
var revives:=1
var revival_clock:=0.0
var resume_phase:="combat"
var missiles:Array=[]
var stones:Array=[]
var ward_remaining:=0.0
var ward_radius:=1.5
var ward_direction:=Vector3.FORWARD
var ward_full_circle:=false
var gameplay_events:Array=[]
var blessing_targets:Dictionary={}
var life_clock:=0.0
var portal_fx_clock:=0.0
var combat_epoch:=0
var healing_amount:=0.0
var stone_serial:=0

func _setup_world() -> void:
	super._setup_world()
	router=CombatFXEvents.new(fx)
	fx.attack_committed.connect(_attack_committed)

func restart() -> void:
	family="lightning";bloodstones=3;revives=1;revival_clock=0;life_clock=0
	missiles.clear();stones.clear();gameplay_events.clear();ward_remaining=0
	if router:router.reset()
	super.restart()
	remove_child(player);player.queue_free()
	player=ExpandedFighter.new();player.name="Zagreus";add_child(player);player.initialize(self)
	player.position=Vector3(0,0,4.3)
	player.action_started.connect(_action_started)
	player.damaged.connect(func(amount):damage_taken+=amount)
	hud.notify("前厅按 1 雷电 / 2 守护 / 3 潮汐 · F 投掷血石 · E 交谈")

func _load_room(index:int) -> void:
	combat_epoch+=1
	missiles.clear();stones.clear();bloodstones=3;ward_remaining=0
	if router:router.reset()
	super._load_room(index)
	portal_fx_clock=0
	# Attach continuous fire to real architectural light sources in this room.
	var count:=0
	for node in art.find_children("*","OmniLight3D",true,false):
		if count>=6:break
		router.emit_event("brazier_fire",{"position":node.global_position-Vector3.UP*.45,"persistent":true,"owner":node,"channel":"fire"})
		record_event("brazier_fire",node.global_position,player,{"fixture":str(node.get_path())})
		count+=1
	router.emit_event("underworld_motes",{"position":player.position+Vector3.UP*.2,"persistent":true})
	record_event("underworld_motes",player.position,player,{"room":index})

func select_family(index:int) -> bool:
	if paused or phase not in ["entry","cleared"] or index<0 or index>=3:return false
	family=FAMILIES[index]
	hud.notify(["雷电：命中连锁 / 新星群雷 / 冲刺落雷","守护：攻击、新星、冲刺均可反弹敌弹","潮汐：击退敌人，撞击实墙造成额外伤害"][index])
	return true

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
			select_family(event.physical_keycode-KEY_1);return
		if event.physical_keycode==KEY_F:
			_update_aim();player.request("cast");return
	super._unhandled_input(event)

func _start_wave() -> void:
	_clear_enemies();wave+=1
	var kinds:Array=["brute","witch"] if wave==1 else (["brute","witch","skull"] if wave==2 else ["boss","brute","witch","skull"])
	for i in range(kinds.size()):
		spawn_enemy(kinds[i],spawn_points[(i+wave-1)%spawn_points.size()])
	_set_phase("combat")
	hud.notify("监军：鞭扫 → 冲锋 → 弹幕 → 连续落点" if wave==3 else "第 %d 波 · 近战 / 远程 / 冲撞"%wave)

func spawn_enemy(kind:String,at:Vector3) -> CharacterBody3D:
	var enemy:=ExpandedEnemy.new();enemy.kind=kind
	enemy.name=kind.capitalize()+"_"+str(enemies.size())
	add_child(enemy);enemy.initialize(self,650.0 if kind=="boss" else (95.0 if kind=="witch" else 80.0 if kind=="skull" else 120.0))
	enemy.position=at;enemy.attack_cooldown=.7+enemies.size()*.27
	enemies.append(enemy)
	_world_event("spawn",at)
	return enemy

func _world_event(kind:String,pos:Vector3) -> void:
	if kind=="heal" and healing_amount<=0:return
	super._world_event(kind,pos)
	record_event("event_"+kind,pos,player,{"world_event":kind,"healing":healing_amount if kind=="heal" else 0.0})

func choose_boon(index:int) -> void:
	if phase!="boon" or selected_boon>=0 or index<0 or index>2:return
	var maximum:float=125 if index==1 else player.max_health
	healing_amount=minf(maximum,player.health+20+(25 if index==1 else 0))-player.health
	super.choose_boon(index)

func record_fx(id:String,at_position:Variant=null) -> void:
	var pos:Vector3=player.position if at_position==null else at_position
	record_event(id,pos,player)

func record_event(id:String,pos:Vector3,actor:Node3D=null,detail:Dictionary={}) -> void:
	fx_counts[id]=int(fx_counts.get(id,0))+1
	var entry:Dictionary={"id":id,"time":life_clock,"room":room_index,"wave":wave,"phase":phase,"position":[pos.x,pos.y,pos.z],"player_health":player.health if is_instance_valid(player) else 0,"bloodstones":bloodstones,"family":family,"detail":detail}
	if is_instance_valid(actor):
		entry.actor=actor.name;entry.action=actor.state if "state" in actor else "fixture"
		if "visual" in actor and is_instance_valid(actor.visual):entry.animation=actor.visual.clip
	gameplay_events.append(entry);fx_log.append(entry)

func _action_started(action:String) -> void:
	super._action_started(action)
	if action=="dash":
		blessing_targets.clear()
		apply_blessing("dash",player.position,player.facing)

func _attack_committed(pos:Vector3,direction:Vector3,action:String) -> void:
	blessing_targets.clear()
	var slot:="special" if action=="nova" else "attack"
	if family!="lightning":apply_blessing(slot,pos,direction)

func apply_blessing(slot:String,pos:Vector3,direction:Vector3) -> void:
	if family=="lightning":
		if slot=="dash":
			var candidates:=targets_near(pos,2.2)
			if not candidates.is_empty():lightning_hit(candidates[0],slot)
		return
	fx.boon(pos,direction,family,slot)
	record_event(family+"_"+slot,pos,player,{"active_action":player.state})
	if family=="deflect":
		ward_remaining=.38 if slot=="special" else .24
		ward_radius=3.15 if slot=="special" else 1.5
		ward_direction=direction;ward_full_circle=slot=="special"
	elif slot=="dash":
		for target in targets_near(pos,1.65):
			damage_enemy(target,10,direction,7,"tide_dash")
			target.wall_armed=true

func targets_near(pos:Vector3,reach:float,except:Node3D=null) -> Array:
	var result:Array=[]
	for e in enemies:
		if not e.dead and e!=except and e.position.distance_to(pos)<=reach and has_combat_line(pos,e.position):result.append(e)
	result.sort_custom(func(a,b):return a.position.distance_squared_to(pos)<b.position.distance_squared_to(pos))
	return result

func lightning_hit(target:Node3D,slot:String) -> void:
	if target.dead or blessing_targets.has(target.get_instance_id()):return
	blessing_targets[target.get_instance_id()]=true
	var points:Array[Vector3]=[target.position+Vector3.UP*3.5,target.position+Vector3.UP]
	fx.lightning(points)
	record_event("lightning_"+slot,target.position,player,{"target":target.name,"damage":14})
	damage_enemy(target,14,player.facing,0,"lightning")
	var nearby:=targets_near(target.position,4.0,target)
	var path:Array[Vector3]=[target.position+Vector3.UP]
	for e in nearby.slice(0,2):
		if blessing_targets.has(e.get_instance_id()):continue
		blessing_targets[e.get_instance_id()]=true
		path.append(e.position+Vector3.UP)
		damage_enemy(e,10,player.facing,0,"chain")
	if path.size()>1:
		fx.lightning(path);record_event("chain",target.position,player,{"jumps":path.size()-1,"damage_each":10})

func confirm_hit(enemy:CharacterBody3D,amount:float,data:Dictionary,result:Dictionary) -> void:
	super.confirm_hit(enemy,amount,data,result)
	if result.get("ignored",false):return
	if family=="lightning":lightning_hit(enemy,"special" if player.state=="nova" else "attack")
	elif family=="tide" and not enemy.dead:
		enemy.push_velocity+=player.facing*8
		enemy.wall_armed=true

func damage_enemy(enemy:Node3D,amount:float,direction:Vector3,push:float,action:String) -> void:
	if enemy.dead:return
	var result:Dictionary=enemy.take_hit(amount,direction,push,action)
	if result.get("ignored",false):return
	if result.killed:kills+=1
	total_damage+=amount;hit_count+=1
	hud.damage_number(enemy.position,amount)
	hit_log.append({"time":life_clock,"action":action,"enemy":enemy.name,"damage":amount,"killed":result.killed})

func cast_stone(origin:Vector3,direction:Vector3) -> void:
	if bloodstones<=0:return
	bloodstones-=1
	var shot:=Missile.new();shot.start(self,origin,direction,player,true);missiles.append(shot)

func shoot(origin:Vector3,direction:Vector3,caster:Node3D,reach:=12.0) -> void:
	var shot:=Missile.new();shot.distance_left=reach;shot.start(self,origin,direction,caster);missiles.append(shot)

func embed_stone(enemy:Node3D) -> void:
	stone_serial+=1
	var marker:=router.emit_event("stone_embedded",{"position":enemy.position+Vector3.UP*2.5,"owner":enemy,"channel":"stone_"+str(stone_serial)})
	for effect in fx.effects:
		if effect.node==marker or marker.is_ancestor_of(effect.node):
			effect.loop=false;effect.erase("flow_time")
	stones.append({"state":"embedded","owner":weakref(enemy),"pos":enemy.position,"time":2.2,"visual":marker})
	record_event("stone_embedded",enemy.position,enemy,{"release_after":2.2})

func drop_stone(pos:Vector3) -> void:
	pos.y=.8
	var marker:=router.emit_event("stone_drop",{"position":pos,"replace":false})
	# The dropped stone remains until collected, rather than timing out as a preview.
	for effect in fx.effects:
		if effect.node==marker or marker.is_ancestor_of(effect.node):effect.critical=true
	stones.append({"state":"ground","pos":Vector3(pos.x,.18,pos.z),"time":.45,"visual":marker})
	record_event("stone_drop",pos,player,{"recoverable":true})

func _tick_stones(delta:float) -> void:
	for s in stones.duplicate():
		s.time-=delta
		if s.state in ["ground","embedded"] and is_instance_valid(s.visual):
			for effect in fx.effects:
				if effect.node==s.visual or s.visual.is_ancestor_of(effect.node):effect.life=effect.total
		if s.state=="embedded":
			var owner_actor:Node3D=s.owner.get_ref()
			if is_instance_valid(owner_actor):s.pos=owner_actor.position
			if not is_instance_valid(owner_actor) or owner_actor.dead or s.time<=0:
				fx.cancel(s.visual);stones.erase(s);drop_stone(s.pos)
		elif s.state=="ground" and s.time<=0 and player.position.distance_to(s.pos)<1.4:
			fx.cancel(s.visual)
			s.visual=router.emit_event("stone_pickup",{"position":s.pos,"target":player.position+Vector3.UP,"replace":false})
			s.state="returning";s.time=.40
			record_event("stone_pickup",s.pos,player,{"arrival_in":.4})
		elif s.state=="returning":
			for effect in fx.effects:
				if effect.node==s.visual and effect.has("travel_curve"):effect.travel_curve[2]=player.position+Vector3.UP
			if s.time<=0:bloodstones=mini(3,bloodstones+1);stones.erase(s)

func begin_revive() -> void:
	revives-=1;revival_clock=1.1;resume_phase=phase
	player.health=0;player.dead=true;player.state="reviving";player.visual.play("death")
	player.clear_input();ward_remaining=0;hit_stop=0
	for enemy in enemies:enemy.cancel_attack()
	for shot in missiles:fx.cancel(shot.visual)
	missiles.clear()
	_set_phase("reviving")
	_world_event("revive",player.position)

func finish(won:bool) -> void:
	# Resolve owner death before the victory clock freezes the room.
	_tick_stones(0)
	for shot in missiles:fx.cancel(shot.visual)
	missiles.clear();ward_remaining=0
	super.finish(won)

func advance(delta:float) -> void:
	if paused or phase in ["boon","dialogue","reward"]:return
	if phase=="reviving":
		fx.tick(delta);revival_clock-=delta
		var age:float=1.1-revival_clock
		var anim:AnimationPlayer=player.visual.anim
		var length:float=anim.get_animation(player.visual.animation_names.death).length
		var pose:float=smoothstep(0,.35,age) if age<.35 else 1.0-smoothstep(.35,1.05,age)
		anim.pause();anim.seek(length*pose,true)
		if revival_clock<=0:
			player.dead=false;player.health=player.max_health*.5;player.state="idle";player.hurt_invuln=1.5
			player.visual.play("idle");_set_phase(resume_phase);hud.notify("死亡反抗 · 恢复一半生命")
		return
	var frozen:bool=hit_stop>0
	super.advance(delta)
	if frozen or phase in ["victory","defeat"]:return
	life_clock+=delta
	ward_remaining=maxf(0,ward_remaining-delta)
	for shot in missiles.duplicate():
		if phase=="reviving":break
		shot.tick(delta)
	missiles=missiles.filter(func(s):return s.alive)
	_tick_stones(delta)
	if phase in ["entry","cleared"]:
		portal_fx_clock-=delta
		if portal_fx_clock<=0:
			portal_fx_clock=1.7;_world_event("exit",portal_position)
