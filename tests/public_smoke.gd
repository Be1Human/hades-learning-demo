extends SceneTree
## Controlled frontend branch test. Victory/defeat are intentionally injected;
## natural combat is verified separately by capture_final_demo.gd.
var app:Node
var checks:Array=[]
var output:=""

func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks.append({"passed":ok,"label":label})
	if not ok:push_error(label)
func key(code:int) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true
	Input.parse_input_event(e);await process_frame
	e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await process_frame
	await frames(4)
func click(button:Button) -> void:
	var p:=button.get_global_rect().get_center()
	var m:=InputEventMouseMotion.new();m.position=p;root.push_input(m,true)
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed
		root.push_input(e,true);await process_frame
	await frames(4)
func frames(count:int) -> void:
	for i in range(count):await process_frame
func run() -> void:
	output=ProjectSettings.globalize_path("res://build/test-results/menu")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	app=load("res://scenes/frontend/main.tscn").instantiate()
	app.settings_path=output+"/settings.cfg"
	if FileAccess.file_exists(app.settings_path):DirAccess.remove_absolute(app.settings_path)
	root.add_child(app);await frames(4)
	check(app.screen=="main" and root.gui_get_focus_owner()==app.view.focus_buttons[0],"Menu starts with focused Start action")
	await click(app.view.focus_buttons[1])
	await key(KEY_RIGHT)
	await click(app.view.focus_buttons[0])
	var saved:=ConfigFile.new()
	check(saved.load(app.settings_path)==OK and is_equal_approx(saved.get_value("audio","volume"),.81) and saved.get_value("audio","muted"),"Keyboard volume and mouse mute save actual values")
	check(AudioServer.is_bus_mute(0) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),.81),"Saved settings change actual master bus")
	await key(KEY_ESCAPE)
	await key(KEY_ENTER)
	check(app.screen=="gameplay" and app.game.phase=="entry","Enter starts real run")
	var first_id:int=app.game.get_instance_id()
	await key(KEY_ESCAPE)
	var before:float=app.game.run_time
	await frames(12)
	check(app.screen=="pause" and app.game.run_time==before and app.game.audio.suspended,"Pause suspends clock and audio")
	await click(app.view.focus_buttons[1])
	await key(KEY_ESCAPE)
	check(app.screen=="pause" and app.game.paused,"Settings escape returns to paused run")
	await click(app.view.focus_buttons[3])
	check(app.game.get_instance_id()!=first_id and app.game.phase=="entry" and app.game.player.health==100,"Pause restart replaces game with clean run")
	for won in [true,false]:
		app.game.finish(won)
		await frames(100)
		check(app.screen=="result" and app.game.phase==("victory" if won else "defeat"),"Injected %s branch reaches results"%str(won))
		var old_id:int=app.game.get_instance_id()
		await key(KEY_ENTER)
		check(app.screen=="gameplay" and app.game.get_instance_id()!=old_id and app.game.selected_boon==-1 and app.game.coins==0 and app.game.bloodstones==3 and app.game.revives==1,"Results retry creates clean resources and run (%s)"%str(won))
	await key(KEY_ESCAPE)
	await click(app.view.focus_buttons[4])
	check(app.screen=="main" and not is_instance_valid(app.game),"Pause return destroys world")
	var replacement=load("res://scenes/frontend/main.tscn").instantiate()
	replacement.settings_path=app.settings_path
	app.queue_free();await frames(2)
	app=replacement;root.add_child(app);await frames(4)
	check(is_equal_approx(app.settings.volume,.81) and app.settings.muted,"New frontend instance reloads saved settings")
	var failed:int=checks.filter(func(c):return not c.passed).size()
	FileAccess.open(output+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"success":failed==0,"methodology":"InputEvent menu actions; victory and defeat intentionally injected through game.finish for frontend branch coverage. This is not natural combat evidence.","passed":checks.size()-failed,"failed":failed,"checks":checks},"  "))
	app.queue_free();await frames(2)
	print("FINAL_MENU_FLOW passed=",checks.size()-failed," failed=",failed)
	quit(0 if failed==0 else 1)
