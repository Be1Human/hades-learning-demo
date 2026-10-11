extends RefCounted
## Shared by the lab and automated checks; every preset calls production FX APIs.

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec in [["slash_1","第一段挥斩"],["slash_2","第二段反斩"],["thrust","终结直刺"],["dash_strike","冲刺直刺"],["dash","冲刺残影"],["dust","脚步尘土"],["charge","新星蓄力"],["nova","新星落地"],["hit","轻命中"],["heavy","重命中"],["armor","护甲命中"],["break","护甲破碎"],["backstab","背刺"],["hurt","玩家受伤"],["death","敌人死亡"],["player_death","玩家死亡"],["warning","敌人读招"],["enemy_swing","敌人挥击"]]:
		result.append({"id":spec[0],"title":spec[1],"integrated":true})
	for phase in ["cast","embedded","drop","pickup"]:
		result.append({"id":"stone_"+phase,"title":"血石 / "+phase,"integrated":true})
	result.append({"id":"projectile","title":"敌方远程弹体","integrated":true})
	result.append({"id":"chain","title":"雷电连锁","integrated":true})
	for family in ["lightning","deflect","tide"]:
		for slot in ["attack","special","dash"]:
			result.append({"id":family+"_"+slot,"title":{"lightning":"雷电","deflect":"守护","tide":"潮汐"}[family]+" / "+slot,"integrated":true})
	result.append({"id":"wall","title":"撞墙冲击","integrated":true})
	for move in ["whip","rush","barrage","blast"]:
		result.append({"id":"boss_"+move,"title":"Boss / "+move,"integrated":true})
		result.append({"id":"boss_warning_"+move,"title":"Boss 预警 / "+move,"integrated":true})
	for event in ["spawn","reward","heal","revive","exit"]:
		result.append({"id":"event_"+event,"title":"局内事件 / "+event,"integrated":true})
	for spec in [["witch_cast","女巫施法"],["witch_impact","女巫弹体命中"],["skull_warning","骷髅冲撞预警"],["skull_rush","骷髅冲撞"],["skull_impact","骷髅撞击"],["reflected_projectile","反弹弹体"],["brazier_fire","火盆火焰"],["underworld_motes","冥界游离光点"]]:
		result.append({"id":spec[0],"title":spec[1],"integrated":true})
	return result

static func play(fx: CombatFX, id: String, pos := Vector3.ZERO, direction := Vector3.FORWARD, visual: ActorVisual = null) -> void:
	if CombatRules.ACTIONS.has(id):
		fx.attack(pos,direction,id)
	elif id.begins_with("stone_"):
		var phase := id.trim_prefix("stone_")
		if phase == "embedded": fx.bloodstone(pos+Vector3.UP*2.45,phase)
		elif phase == "pickup": fx.bloodstone(pos+direction*3+Vector3.UP*0.3,phase,pos+Vector3.UP*0.9)
		elif phase == "drop": fx.bloodstone(pos+direction*1.4+Vector3.UP*0.65,phase)
		else: fx.bloodstone(pos+Vector3.UP*0.9,phase,pos+direction*3+Vector3.UP)
	elif id.begins_with("event_"):
		fx.world_event(pos,id.trim_prefix("event_"))
	elif id.begins_with("boss_warning_"): fx.boss_warning(pos,direction,id.trim_prefix("boss_warning_"))
	elif id.begins_with("boss_"): fx.boss(pos,direction,id.trim_prefix("boss_"))
	elif id.get_slice("_",0) in ["lightning","deflect","tide"]:
		fx.boon(pos,direction,id.get_slice("_",0),id.get_slice("_",1))
	else:
		match id:
			"dash":
				fx.dash_burst(pos,direction)
				if visual != null: fx.afterimage(visual,Color(0.4,0.85,1,0.32))
			"dust": fx.dust(pos)
			"charge": fx.charge(pos,CombatFX.GOLD)
			"hit","heavy","armor","break": fx.impact(pos,direction,id in ["heavy","break"],id in ["armor","break"],id == "break")
			"backstab": fx.backstab(pos)
			"hurt","player_death": fx.hurt(pos,id == "player_death")
			"death": fx.death(pos)
			"warning": fx.warning(pos,2.45,0.64,direction,2.0*acos(0.25))
			"enemy_swing": fx.enemy_swing(pos,direction)
			"projectile": fx.projectile(pos+Vector3.UP,pos+direction*5+Vector3.UP,0.8,true)
			"chain": fx.lightning([pos+Vector3.UP*3,pos+Vector3.UP,pos+Vector3(2,1,-1),pos+Vector3(-1,1,-2)])
			"wall": fx.wall_hit(pos,-direction)
			"witch_cast": fx.witch_cast(pos,direction)
			"witch_impact": fx.witch_impact(pos+Vector3.UP,direction)
			"skull_warning": fx.skull_warning(pos,direction)
			"skull_rush": fx.skull_rush(pos,direction)
			"skull_impact": fx.skull_impact(pos,direction)
			"reflected_projectile": fx.reflected_projectile(pos+Vector3.UP,pos-direction*4+Vector3.UP)
			"brazier_fire","underworld_motes": fx.ambient(pos,id)
