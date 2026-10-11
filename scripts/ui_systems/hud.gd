extends "res://scripts/frontend/view.gd"
var arena:Node3D
var health_frame:Texture2D
var health_clip:Control
var health_text:Label
var objective:Label
var resources:Label
var dash_text:Label
var boon_text:Label
var notice_text:Label
var notice_left:=0.0
var last_action:=""
var names:={"slash_1":"挥斩","slash_2":"反斩","thrust":"直刺","dash":"冲刺","dash_strike":"冲刺攻击","nova":"新星"}
var floaters:Array=[]
var boon_icon:TextureRect
var enemy_fill:Texture2D

func _ready() -> void:
	super._ready()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	health_frame=texture("health-track-v04")
	enemy_fill=texture("health-fill-v01")
	picture("health-track-v04",Rect2(42,970,460,58))
	health_clip=Control.new()
	health_clip.position=Vector2(57,990)
	health_clip.size=Vector2(423,18)
	health_clip.clip_contents=true
	health_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(health_clip)
	picture("health-fill-v01",Rect2(0,0,423,18),health_clip)
	health_text=label("",Rect2(514,970,270,55),34,Color("eee5da"),"body")
	dash_text=label("",Rect2(60,1030,400,42),23)
	objective=label("",Rect2(575,30,770,65),26,Color("d4c099"),"cn",true)
	resources=label("",Rect2(1520,960,340,75),27,Color("dec895"),"cn",true)
	boon_icon=picture("boon-athena-attack-v01",Rect2(24,410,112,112))
	boon_icon.hide()
	boon_text=label("",Rect2(25,533,210,90),20)
	boon_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notice_text=label("",Rect2(450,875,1020,55),27,Color("dbce98"),"cn",true)
	label("WASD 移动    左键攻击    空格冲刺    右键 / Q 新星    Esc 暂停",Rect2(530,1031,1320,40),20,Color("c5c5b3"),"cn",true)

func clear() -> void:
	for f in floaters:
		if is_instance_valid(f.node):f.node.queue_free()
	floaters.clear()
	notice_left=0
	last_action=""

func notify(value:String) -> void:
	if is_instance_valid(notice_text):notice_text.text=value
	notice_left=2.5

func damage_number(pos:Vector3,amount:float) -> void:
	var n:=label(str(roundi(amount)),Rect2(0,0,100,40),30,Color("f7d7a5"),"title",true)
	floaters.append({"node":n,"pos":pos+Vector3.UP*1.9,"life":.65})

func sync() -> void:
	if not is_instance_valid(arena) or not is_instance_valid(arena.player):return
	var hp:float=clampf(arena.player.health/arena.player.max_health,0,1)
	health_clip.size.x=423*hp
	health_text.text="%d / %d"%[arena.player.health,arena.player.max_health]
	health_text.modulate=Color("ff806b") if hp<=.25 else Color.WHITE
	dash_text.text="冲刺就绪" if arena.player.dash_cooldown<=0 else "冲刺恢复  %.2f s"%arena.player.dash_cooldown
	resources.text="冥币  %d     击倒  %d"%[arena.coins,arena.kills]
	var target:String={"entry":"前往冥门 · E 交谈","intro":"准备战斗","combat":"第 %d / 3 波 · 剩余 %d"%[arena.wave,arena.living_enemies()],"intermission":"下一波即将到来","cleared":"前往光门 · E 领取奖励"}.get(arena.phase,"")
	objective.text="%s  /  %s"%[arena.ROOM_NAMES[arena.room_index],target]
	boon_icon.visible=arena.selected_boon>=0
	if arena.selected_boon>=0:
		boon_icon.texture=texture(["boon-athena-attack-v01","boon-athena-cast-v01","boon-athena-dash-v01"][arena.selected_boon])
		boon_text.text=["利刃\n武器伤害 +30%","坚毅之心\n最大生命 +25","疾步\n冲刺恢复 -25%"][arena.selected_boon]
	else:boon_text.text=""
	if "family" in arena:
		resources.text="血石 %d / 3   反抗 %d\n冥币 %d   击倒 %d"%[arena.bloodstones,arena.revives,arena.coins,arena.kills]
		boon_text.text={"lightning":"雷电 · 命中连锁","deflect":"守护 · 出招反弹","tide":"潮汐 · 击退撞墙"}[arena.family]+"\nF 血石投射"
		if arena.phase in ["entry","cleared"]:boon_text.text+="\n1 / 2 / 3 选择神力"
		if arena.phase=="reviving":objective.text="死亡反抗 · 重返战斗"

func _process(delta:float) -> void:
	sync()
	queue_redraw()
	if not is_instance_valid(arena) or arena.paused:return
	notice_left=maxf(0,notice_left-delta)
	notice_text.visible=notice_left>0
	for i in range(floaters.size()-1,-1,-1):
		var f:Dictionary=floaters[i]
		f.life-=delta
		f.pos.y+=delta*.8
		f.node.position=(arena.camera.unproject_position(f.pos)-stage.position)/stage.scale-Vector2(50,0)
		f.node.modulate.a=clampf(f.life*4,0,1)
		if f.life<=0:
			f.node.queue_free()
			floaters.remove_at(i)

func _draw() -> void:
	if not is_instance_valid(arena) or health_frame==null or enemy_fill==null:return
	for enemy in arena.enemies:
		if not is_instance_valid(enemy) or enemy.dead or not arena.camera.is_position_in_frustum(enemy.global_position):continue
		var point:Vector2=arena.camera.unproject_position(enemy.global_position+Vector3.UP*2.7)
		draw_texture_rect(health_frame,Rect2(point-Vector2(34,0),Vector2(68,10)),false)
		var ratio:float=clampf(enemy.health/enemy.max_health,0,1)
		if ratio>0:draw_texture_rect(enemy_fill,Rect2(point-Vector2(31,-3),Vector2(60*ratio,4)),false)
