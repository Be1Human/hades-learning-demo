extends "res://scripts/demo01/hud.gd"
func _draw() -> void:
	super._draw()
	if not is_instance_valid(arena) or arena.phase=="boon":return
	# Replace only the old single-room heading; keep the handed-off health art.
	draw_rect(Rect2(size.x*.5-240,0,480,103),Color(.018,.028,.033,1))
	centered("%02d / 03   %s"%[arena.room_index+1,arena.ROOM_NAMES[arena.room_index]],38,23,gold)
	ornament(53,150,Color("8b784f"))
	var objective:=""
	match arena.phase:
		"entry":objective="WASD 移动 · 在冥门前按 E 开始试炼"
		"cleared":objective="前往光门 · 按 E 领取祝福并继续"
		"intro":objective="准备战斗  %d"%ceili(arena.phase_clock)
		"intermission":objective="下一波即将开始  %d"%ceili(arena.phase_clock)
		"combat":objective="第 %d / 3 波 · 剩余 %d"%[arena.wave,arena.living_enemies()]
		"victory":objective="三间试炼完成"
		"defeat":objective="此路未竟"
	centered(objective,80,17,ivory)
	if arena.selected_boon>=0:
		text(["祝福 · 全部武器伤害 +30%","祝福 · 最大生命 +25","祝福 · 冲刺冷却 -25%"][arena.selected_boon],Vector2(40,40),17,gold)
	if not arena.paused and arena.phase in ["entry","cleared"]:
		var p:Vector2=arena.camera.unproject_position(arena.portal_position+Vector3.UP*1.5)
		text("[ E ] 进入试炼" if arena.phase=="entry" else "[ E ] 领取祝福",p+Vector2(-65,0),19,Color("b7ebc7") if arena.near_portal() else dim)
