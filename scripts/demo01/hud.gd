extends Control
var arena: Node3D
var font: SystemFont
var floaters: Array=[]
var notice:=""
var notice_left:=0.0
var last_action:="冥界之刃"
var names:={"slash_1":"一段 · 挥斩","slash_2":"二段 · 反斩","thrust":"三段 · 直刺","dash":"冲刺","dash_strike":"冲刺攻击","nova":"特殊 · 新星"}
var gold:=Color("dab976")
var ivory:=Color("f0e3c9")
var dim:=Color("b8b09d")
var health_frame: Texture2D
var resume_button: Button
var restart_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","Arial"])
	font.font_weight=500
	var source:=load("res://assets/ui/r02/raster/health-track-v04.png") as Texture2D
	if source:
		var atlas:=AtlasTexture.new()
		atlas.atlas=source
		atlas.region=Rect2(27,554,1198,144)
		health_frame=atlas
	resume_button=_button("继续试炼  [Esc]",func():arena.set_paused(false))
	restart_button=_button("重新开始  [R]",func():arena.restart())

func _button(label: String,callback: Callable) -> Button:
	var button:=Button.new()
	button.text=label
	button.add_theme_font_override("font",font)
	button.add_theme_font_size_override("font_size",20)
	button.add_theme_color_override("font_color",ivory)
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	button.add_theme_color_override("font_focus_color",Color.WHITE)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(.06,.07,.065,.85)
	style.border_color=Color("896a39")
	style.border_width_bottom=2
	style.border_width_top=1
	style.content_margin_left=24
	style.content_margin_right=24
	style.content_margin_top=10
	style.content_margin_bottom=10
	button.add_theme_stylebox_override("normal",style)
	var hover:=style.duplicate()
	hover.bg_color=Color(.21,.17,.11,.95)
	hover.border_color=gold
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("focus",hover)
	button.pressed.connect(callback)
	button.visible=false
	add_child(button)
	return button

func clear() -> void:
	floaters.clear()
	notice=""
	notice_left=0
	last_action="冥界之刃"

func notify(value: String) -> void:
	notice=value
	notice_left=2.3

func damage_number(pos: Vector3,amount: float) -> void:
	floaters.append({"pos":pos+Vector3.UP*1.9,"amount":str(roundi(amount)),"life":.65})

func text(value: String,pos: Vector2,size_value: int,color:=Color.WHITE) -> void:
	draw_string(font,pos+Vector2(1,2),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,Color(0,0,0,.96))
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,color)

func centered(value: String,y: float,size_value: int,color:=Color.WHITE) -> void:
	var width:=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x
	text(value,Vector2((size.x-width)*.5,y),size_value,color)

func ornament(y: float,half_width: float,color: Color) -> void:
	var c:=size.x*.5
	draw_line(Vector2(c-half_width,y),Vector2(c-11,y),color,1)
	draw_line(Vector2(c+11,y),Vector2(c+half_width,y),color,1)
	draw_colored_polygon(PackedVector2Array([Vector2(c,y-5),Vector2(c+5,y),Vector2(c,y+5),Vector2(c-5,y)]),color)

func _process(delta: float) -> void:
	if not is_instance_valid(arena):return
	if not arena.paused:
		notice_left=maxf(0,notice_left-delta)
		for i in range(floaters.size()-1,-1,-1):
			floaters[i].life-=delta
			floaters[i].pos.y+=delta*.8
			if floaters[i].life<=0:floaters.remove_at(i)
	var result: bool=arena.phase=="victory" or (arena.phase=="defeat" and arena.phase_clock<=0)
	resume_button.visible=arena.paused
	restart_button.visible=arena.paused or result
	resume_button.position=Vector2(size.x*.5-150,size.y*.5+48)
	resume_button.size=Vector2(300,48)
	restart_button.position=Vector2(size.x*.5-150,size.y*.5+(111 if arena.paused else 75))
	restart_button.size=Vector2(300,48)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(arena) or not is_instance_valid(arena.player):return
	var w:=size.x
	var h:=size.y
	var hp: float=arena.player.health/arena.player.max_health
	var x:=40.0
	var y:=h-91
	if health_frame:draw_texture_rect(health_frame,Rect2(x,y,348,42),false)
	draw_rect(Rect2(x+9,y+13,327,19),Color("241214"))
	draw_rect(Rect2(x+9,y+13,327*hp,19),Color("9f2735"))
	draw_line(Vector2(x+10,y+14),Vector2(x+10+325*hp,y+14),Color("ef8469"),2)
	text("生命  %d / %d"%[arena.player.health,arena.player.max_health],Vector2(x+17,y+63),17,ivory)
	var ready: bool=arena.player.dash_cooldown<=0
	text("◆ 冲刺就绪" if ready else "◇ 冲刺恢复",Vector2(x+220,y+63),15,Color("aae5dd") if ready else dim)
	centered("塔尔塔罗斯",41,23,gold)
	ornament(58,135,Color("8b784f"))
	var top:="第 %d / 3 波 · 剩余 %d"%[maxi(1,arena.wave),arena.living_enemies()]
	if arena.phase=="intro":top="试炼即将开始  %d"%ceili(arena.phase_clock)
	elif arena.phase=="intermission":top="第 %d 波已清理 · 下一波 %d"%[arena.wave,ceili(arena.phase_clock)]
	centered(top,84,17,ivory)
	text("持剑试炼",Vector2(w-184,41),19,gold)
	text("击杀 %02d    %02d:%02d"%[arena.kills,int(arena.run_time)/60,int(arena.run_time)%60],Vector2(w-184,70),15,ivory)
	text("Esc 暂停    F3 声音",Vector2(w-194,h-29),13,dim)
	centered(last_action,h-81,19,gold)
	centered("WASD 移动   左键 三连击   空格 冲刺   右键 / Q 新星",h-49,15,ivory)
	for enemy in arena.enemies:
		if enemy.dead or not arena.camera.is_position_in_frustum(enemy.global_position):continue
		var p: Vector2=arena.camera.unproject_position(enemy.global_position+Vector3.UP*2.7)
		draw_rect(Rect2(p-Vector2(30,0),Vector2(60,5)),Color("251a1c"))
		draw_rect(Rect2(p-Vector2(30,0),Vector2(60*enemy.health/enemy.max_health,5)),Color("b74044"))
		draw_line(p-Vector2(30,1),p+Vector2(30,-1),Color("c29863"),1)
	for f in floaters:
		var p: Vector2=arena.camera.unproject_position(f.pos)
		text(f.amount,p,26,Color(1,.88,.65,minf(1,float(f.life)*4)))
	if notice_left>0 and arena.phase=="combat":centered(notice,h*.20,22,gold)
	if arena.paused or arena.phase=="victory" or (arena.phase=="defeat" and arena.phase_clock<=0):
		draw_rect(Rect2(Vector2.ZERO,size),Color(.015,.02,.025,.80))
		ornament(h*.5-89,250,gold)
		centered("试炼暂停" if arena.paused else ("试炼完成" if arena.phase=="victory" else "此路未竟"),h*.5-29,45,gold)
		if arena.paused:centered("调整呼吸，再次挥剑。",h*.5+10,19,ivory)
		else:
			centered("击倒 %d 名暴徒  ·  命中 %d 次  ·  用时 %02d:%02d"%[arena.kills,arena.hit_count,int(arena.run_time)/60,int(arena.run_time)%60],h*.5+11,18,ivory)
			centered("三波战斗结束" if arena.phase=="victory" else "重新开始，磨炼下一次进攻。",h*.5+43,16,dim)
