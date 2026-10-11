extends Node
## Owns world lifetime, modal focus and persisted settings; no fabricated continue save.
const RUN=preload("res://scenes/frontend/run.tscn")
var view:Control
var game:Node3D
var screen:="main"
var return_screen:="main"
var busy:=false
var settings_path:="user://frontend-settings.cfg"
var settings:={"volume":.8,"muted":false,"fullscreen":false}
var volume_slider:HSlider
var volume_label:Label
var loading:Label
var last_error:=""

func _ready() -> void:
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_title("Hades · 冥界试炼")
	var canvas:=CanvasLayer.new()
	canvas.layer=100
	add_child(canvas)
	view=preload("res://scripts/frontend/view.gd").new()
	canvas.add_child(view)
	load_settings()
	if "--windowed" in OS.get_cmdline_args():settings.fullscreen=false
	apply_settings()
	show_main()

func load_settings() -> void:
	var config:=ConfigFile.new()
	if config.load(settings_path)!=OK:return
	var volume:Variant=config.get_value("audio","volume",.8)
	if typeof(volume) in [TYPE_INT,TYPE_FLOAT]:settings.volume=clampf(float(volume),0,1)
	var muted:Variant=config.get_value("audio","muted",false)
	var fullscreen:Variant=config.get_value("window","fullscreen",false)
	settings.muted=muted if muted is bool else false
	settings.fullscreen=fullscreen if fullscreen is bool else false

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,settings.volume)))
	AudioServer.set_bus_mute(0,settings.muted)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func save_settings() -> void:
	var config:=ConfigFile.new()
	config.set_value("audio","volume",settings.volume)
	config.set_value("audio","muted",settings.muted)
	config.set_value("window","fullscreen",settings.fullscreen)
	var error:int=config.save(settings_path)
	last_error="设置保存失败：%s"%error if error!=OK else ""

func set_volume(value:float) -> void:
	settings.volume=clampf(value/100,0,1)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,settings.volume)))
	if is_instance_valid(volume_label):volume_label.text="主音量    %d%%"%value
	save_settings()

func toggle_mute() -> void:
	settings.muted=not settings.muted
	apply_settings()
	save_settings()
	show_settings(return_screen)

func toggle_fullscreen() -> void:
	settings.fullscreen=not settings.fullscreen
	apply_settings()
	save_settings()
	show_settings(return_screen)

func _base(title:String) -> void:
	view.clear_view()
	view.show()
	if not is_instance_valid(game):view.raw_picture("res://assets/ui/r03/raster/menu-backdrop-v01.png",Rect2(0,0,1920,1080))
	view.shade(.84)
	view.picture("boon-header-v01",Rect2(385,105,1150,145))
	view.label(title,Rect2(530,131,860,90),48,Color("e6d6b3"),"cn",true)

func show_main() -> void:
	screen="main"
	view.clear_view()
	view.show()
	view.raw_picture("res://assets/ui/r03/raster/menu-backdrop-v01.png",Rect2(0,0,1920,1080))
	view.picture("menu-logo-v01",Rect2(100,60,390,151))
	view.label("冥界 · 持剑试炼",Rect2(114,218,540,60),28,Color("d2bf9c"))
	view.button("开始试炼",Rect2(119,492,440,70),start_new_run,true)
	view.button("设置",Rect2(119,589,440,70),func():show_settings("main"),true)
	view.button("操作说明",Rect2(119,686,440,70),func():show_controls("main"),true)
	view.button("退出游戏",Rect2(119,823,440,70),quit_game,true)
	view.label("冥界之旅 · 持剑试炼",Rect2(114,1001,800,44),22,Color("aaa99e"))
	view.focus_first()

func start_new_run() -> void:
	if busy:return
	busy=true
	dispose_game()
	game=RUN.instantiate()
	add_child(game)
	game.pause_requested.connect(pause_run)
	screen="gameplay"
	view.hide()
	busy=false

func dispose_game() -> void:
	if not is_instance_valid(game):return
	game.set_process_unhandled_input(false)
	game.audio.shutdown()
	remove_child(game)
	game.queue_free()
	game=null

func return_to_menu() -> void:
	if busy:return
	busy=true
	dispose_game()
	show_main()
	busy=false

func pause_run() -> void:
	if not is_instance_valid(game) or screen!="gameplay":return
	game.set_paused(true)
	game.process_mode=Node.PROCESS_MODE_DISABLED
	show_pause()

func show_pause() -> void:
	screen="pause"
	_base("试炼暂停")
	view.button("继续试炼",Rect2(670,366,580,83),resume_run)
	view.button("设置",Rect2(670,475,580,83),func():show_settings("pause"))
	view.button("操作说明",Rect2(670,584,580,83),func():show_controls("pause"))
	view.button("重新开始",Rect2(670,693,580,83),start_new_run)
	view.button("返回主菜单",Rect2(670,802,580,83),return_to_menu)
	view.label("返回主菜单会结束当前试炼",Rect2(600,920,720,45),23,Color("aaa99e"),"cn",true)
	view.focus_first()

func resume_run() -> void:
	if not is_instance_valid(game):return
	game.process_mode=Node.PROCESS_MODE_INHERIT
	game.set_paused(false)
	screen="gameplay"
	view.hide()
	if game.phase in ["dialogue","reward"]:game.flow_view.focus_first()

func show_settings(origin:String) -> void:
	return_screen=origin
	screen="settings"
	_base("设置")
	volume_label=view.label("主音量    %d%%"%roundi(settings.volume*100),Rect2(550,365,810,70),32)
	volume_slider=HSlider.new()
	volume_slider.position=Vector2(555,470)
	volume_slider.size=Vector2(810,60)
	volume_slider.min_value=0
	volume_slider.max_value=100
	volume_slider.step=1
	volume_slider.value=settings.volume*100
	view.stage.add_child(volume_slider)
	volume_slider.value_changed.connect(set_volume)
	view.button("静音："+("开" if settings.muted else "关"),Rect2(550,587,820,80),toggle_mute)
	view.button("显示："+("全屏" if settings.fullscreen else "窗口"),Rect2(550,697,820,80),toggle_fullscreen)
	view.button("返回",Rect2(705,860,510,80),back)
	view.label("设置自动保存 · 音量支持左右方向键",Rect2(550,965,820,42),22,Color("aaa99e"),"cn",true)
	view.focus_first()
	volume_slider.focus_neighbor_bottom=view.focus_buttons[0].get_path()
	view.focus_buttons[0].focus_neighbor_top=volume_slider.get_path()
	volume_slider.grab_focus()

func show_controls(origin:String) -> void:
	return_screen=origin
	screen="controls"
	_base("操作说明")
	var rows=["WASD 移动 / 鼠标瞄准","左键 三连击 / 空格 冲刺与闪避","右键 / Q 新星 / F 血石投射","前厅 1 雷电 / 2 守护 / 3 潮汐","血石命中嵌入，掉落后靠近回收","每局一次死亡反抗，恢复半血","E 交谈 / 领取 / 进入；Esc 暂停","方向键 / Tab / Enter 菜单导航与确认"]
	for i in range(rows.size()):view.label(rows[i],Rect2(590,294+i*63,870,60),28)
	view.button("返回",Rect2(705,868,510,83),back)
	view.focus_first()

func back() -> void:
	if return_screen=="pause":show_pause()
	else:show_main()

func show_death() -> void:
	screen="death"
	game.hud.hide()
	view.clear_view()
	view.show()
	view.shade(.78)
	view.picture("death-banner-v01",Rect2(74,85,1772,224))
	view.label("无处可逃",Rect2(355,140,1210,100),58,Color("c12b29"),"cn",true)

func show_result() -> void:
	if not is_instance_valid(game):return
	screen="result"
	game.hud.hide()
	game.process_mode=Node.PROCESS_MODE_DISABLED
	game.audio.set_suspended(true)
	var won:bool=game.phase=="victory"
	_base("试炼完成" if won else "此路未竟")
	if not won:
		view.picture("death-banner-v01",Rect2(600,269,720,108))
	view.label("%02d:%02d"%[int(game.run_time)/60,int(game.run_time)%60],Rect2(565,380,790,97),76,Color("e6d6b3"),"heading",true)
	view.label("击倒  %d     命中  %d     冥币  %d"%[game.kills,game.hit_count,game.coins],Rect2(480,517,960,64),30,Color("e8e1ce"),"cn",true)
	view.label("造成伤害  %d     承受伤害  %d"%[game.total_damage,game.damage_taken],Rect2(480,590,960,64),28,Color("c1c2b5"),"cn",true)
	var gift:String="未获得祝福" if game.selected_boon<0 else ["利刃 · 武器伤害 +30%","坚毅之心 · 最大生命 +25","疾步 · 冲刺恢复 -25%"][game.selected_boon]
	view.label(gift,Rect2(480,676,960,65),27,Color("aecc86"),"cn",true)
	view.button("再试一次",Rect2(530,838,400,89),start_new_run)
	view.button("返回主菜单",Rect2(990,838,400,89),return_to_menu)
	view.focus_first()

func _process(_delta:float) -> void:
	if not is_instance_valid(game):return
	if screen=="gameplay":
		if game.phase=="defeat":show_death()
		elif game.phase=="victory":show_result()
	elif screen=="death" and game.phase_clock<=0:show_result()

func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		match screen:
			"gameplay":pause_run()
			"pause":resume_run()
			"settings","controls":back()
		get_viewport().set_input_as_handled()

func quit_game() -> void:
	dispose_game()
	get_tree().quit()

func _exit_tree() -> void:
	if is_instance_valid(game):game.audio.shutdown()
