extends SceneTree
## Run with --main-pack and this absolute script path to verify shipped resources.
var passed:Array=[]
var failed:Array=[]
var game:Node3D
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	(passed if ok else failed).append(label)
	if not ok:push_error(label)
func steps(n:int)->void:
	for i in range(n):game.advance(1.0/60)
func setup()->void:
	game.restart();game.test_control=true;game.enemy_ai=false
	game._load_room(2);game._set_phase("combat");game.wave=3
	game.player.position=Vector3(0,0,1.5);game.player.aim_direction=Vector3.FORWARD
func run()->void:
	var output:String=ProjectSettings.globalize_path("res://build/test-results/combat")
	if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var app=load("res://scenes/frontend/main.tscn").instantiate()
	app.settings_path=output+"/pack-settings.cfg";root.add_child(app);await process_frame
	check(app.screen=="main","Pack boots default menu")
	app.start_new_run();game=app.game;game.set_physics_process(false);game.test_control=true
	check(game.player.get_script().resource_path=="res://scripts/gameplay/fighter.gd","Pack loads expanded production fighter")
	setup();var target=game.spawn_enemy("brute",Vector3(0,0,-.2))
	game.player.request("cast");steps(30)
	check(game.bloodstones==2 and target.health<120,"Packed cast consumes resource and damages actual enemy")
	check(game.stones.size()==1,"Packed bloodstone embeds")
	setup();game.family="deflect";game.enemy_ai=true
	var witch=game.spawn_enemy("witch",Vector3(0,0,-2.5));witch.health=500;witch.attack_cooldown=0
	steps(54);game.player.request("attack");steps(100)
	check(witch.health<500,"Packed ward returns actual projectile to caster")
	setup();game.enemy_ai=true;game.player.health=8
	witch=game.spawn_enemy("witch",Vector3(0,0,-2.2));witch.attack_cooldown=0;steps(140)
	check(game.revives==0 and game.player.health==50 and not game.player.dead,"Packed fatal AI hit revives player")
	for move in ["whip","rush","barrage","blast"]:
		setup();game.enemy_ai=true
		var boss=game.spawn_enemy("boss",Vector3(0,0,-1.5));boss.attack_cooldown=0;boss.move_index=["whip","rush","barrage","blast"].find(move)
		steps(160);check(game.player.health<100,"Packed boss attack damages player: "+move)
	app.return_to_menu();await process_frame
	check(app.screen=="main" and not is_instance_valid(app.game),"Packed run returns to menu and disposes world")
	FileAccess.open(output+"/pack-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	app.queue_free();await process_frame
	print("R06_PACK passed=",passed.size()," failed=",failed.size());quit(0 if failed.is_empty() else 1)
