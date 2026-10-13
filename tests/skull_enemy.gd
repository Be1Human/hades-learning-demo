extends SceneTree
## Run with --headless --fixed-fps 60 --script <this file> -- --output=<directory>.
## No editor-only dependencies: also works as an external script with --main-pack.
const MODEL := "res://assets/characters/skull-r01/skull.glb"
const STEP := 1.0 / 60.0
var game: Node3D
var passed: Array = []
var failed: Array = []
var observations: Dictionary = {}
var output := "res://evidence/skull-r01/tests"
var source_hashes: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	(passed if ok else failed).append(label)
	if not ok: push_error(label)

func step(count: int) -> void:
	for i in range(count): game.advance(STEP)

func setup() -> void:
	game.set_paused(false)
	game.restart()
	game._load_room(2)
	game._set_phase("combat")
	game.wave = 3
	game.enemy_ai = false
	game.test_control = true
	game.player.position = Vector3(0, 0, 1.5)
	game.player.hurt_invuln = 0
	game.player.move_axis = Vector3.ZERO
	game.hit_stop = 0

func spawn(kind: String = "skull", at: Vector3 = Vector3(0, 0, -1.6)) -> Node3D:
	return game.spawn_enemy(kind, at)

func event_count(id: String) -> int:
	return game.gameplay_events.filter(func(event): return event.id == id).size()

func actual_material(part: MeshInstance3D, surface: int) -> Material:
	return part.material_override if part.material_override != null else part.get_active_material(surface)

func visible_shader_values(actor: Node3D, parameter: String) -> Array:
	var values: Array = []
	for node in actor.visual.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if not part.is_visible_in_tree() or part.mesh == null: continue
		for surface in range(part.mesh.get_surface_count()):
			var material := actual_material(part, surface)
			if material is ShaderMaterial: values.append(material.get_shader_parameter(parameter))
	return values

func visual_snapshot(actor: Node3D) -> Dictionary:
	var transforms: Dictionary = {}
	for node in actor.visual.find_children("*", "Node3D", true, false):
		transforms[str(actor.visual.get_path_to(node))] = node.transform
	return {"actor": actor.transform, "visual": actor.visual.transform,
		"children": transforms, "clock": actor.clock,
		"flash": visible_shader_values(actor, "flash_amount"),
		"emission": visible_shader_values(actor, "emission_strength")}

func model_and_materials() -> void:
	setup()
	var skull := spawn()
	step(3)
	var visual: Node3D = skull.visual
	check(visual.get_script().resource_path == "res://scripts/gameplay/skull_visual.gd", "Spawn selects the dedicated skull visual")
	check(is_instance_valid(visual.model) and visual.model.scene_file_path == MODEL, "Skull instantiates the authored skull GLB")
	check(visual.model.is_visible_in_tree(), "Authored skull model is visible")
	check(visual.skeleton == null and visual.anim == null and visual.weapon == null, "Skull has no humanoid skeleton, animation player or attached club")
	check(visual.find_children("*", "Skeleton3D", true, false).is_empty(), "Skull subtree contains no hidden humanoid skeleton")
	var all_meshes: Array = visual.find_children("*", "MeshInstance3D", true, false)
	var inside_model := true
	var all_lit := not all_meshes.is_empty()
	var all_shaded := not all_meshes.is_empty()
	var names: Array = []
	for part in all_meshes:
		names.append(String(part.name))
		inside_model = inside_model and visual.model.is_ancestor_of(part)
		all_lit = all_lit and part.layers == 3
		all_shaded = all_shaded and part.mesh is ArrayMesh and part.is_visible_in_tree()
		if part.mesh != null:
			for surface in range(part.mesh.get_surface_count()):
				all_shaded = all_shaded and actual_material(part, surface) is ShaderMaterial
	check(inside_model and all_meshes.size() == visual.meshes.size(), "All skull meshes belong to its GLB; no extra procedural head or hidden body")
	check(all_lit, "Every skull mesh uses lighting layers 1 and 2 (mask 3)")
	check(all_shaded, "Visible skull meshes use imported geometry and active ShaderMaterials")
	for part_name in ["Cranium", "Mandible", "UpperTeeth", "LowerTeeth", "EmberEyeL", "EmberEyeR", "BoneSutures"]:
		var part := visual.model.find_child(part_name, true, false) as MeshInstance3D
		check(part != null and part.mesh is ArrayMesh and part.mesh.get_surface_count() > 0,
			"GLB contains renderable " + part_name)
	var jaw := visual.model.find_child("JawPivot", true, false) as Node3D
	var lower: Node = visual.model.find_child("LowerTeeth", true, false)
	check(jaw != null and lower != null and jaw.is_ancestor_of(lower), "Lower teeth follow the authored JawPivot")
	var cranium := visual.model.find_child("Cranium", true, false) as MeshInstance3D
	var colored := cranium != null and cranium.mesh is ArrayMesh
	var vertex_count := 0
	if colored:
		for surface in range(cranium.mesh.get_surface_count()):
			var arrays := cranium.mesh.surface_get_arrays(surface)
			vertex_count += arrays[Mesh.ARRAY_VERTEX].size()
			colored = colored and arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size()
	check(colored and vertex_count > 0, "Cranium geometry carries a color for every rendered vertex")
	observations.model = {"scene": visual.model.scene_file_path, "mesh_names": names, "cranium_vertices": vertex_count,
		"cavity_scope": "Eye sockets and nasal cavity are boolean cuts in Cranium; their shape is assessed in native visual comparison, not inferred from names."}
	game.damage_enemy(skull, 1, Vector3.FORWARD, 0, "skull_test_hit")
	step(1)
	var flashes := visible_shader_values(skull, "flash_amount")
	check(not flashes.is_empty() and flashes.all(func(value): return value != null and float(value) > 0), "A real damage event flashes all active visible skull ShaderMaterials")
	step(8)
	check(visible_shader_values(skull, "flash_amount").all(func(value): return value != null and is_zero_approx(float(value))), "Hit flash clears after its real timer")

func charge_contact() -> void:
	setup()
	var skull := spawn()
	game.enemy_ai = true
	skull.attack_cooldown = 0
	step(1)
	game.enemy_ai = false
	check(skull.state == "attack" and event_count("skull_warning") == 1, "Production skull AI enters windup and creates one warning")
	check(is_instance_valid(skull.telegraph) and skull.telegraph.visible, "Windup owns a visible telegraph")
	step(32)
	check(not skull.attack_applied and event_count("skull_rush") == 0, "Rush cannot release before 0.55 seconds")
	step(2)
	check(skull.attack_applied and event_count("skull_rush") == 1 and skull.clock >= 0.55 and skull.clock <= 0.55 + STEP * 1.1, "Rush releases at the 0.55-second threshold within one fixed step")
	check(not is_instance_valid(skull.telegraph) or not skull.telegraph.visible, "Release clears its windup marker")
	step(25)
	check(is_equal_approx(game.player.health, 88.0) and event_count("skull_impact") == 1, "One real skull contact applies exactly 12 damage and one impact")
	# Clear hurt immunity while keeping the actors touching: recovery, not immunity,
	# must prevent a second hit from the same committed rush.
	game.player.hurt_invuln = 0
	game.player.position = skull.position + Vector3(0, 0, 0.2)
	game.player.push_velocity = Vector3.ZERO
	step(90)
	check(is_equal_approx(game.player.health, 88.0) and event_count("skull_impact") == 1, "Finished rush cannot damage a touching player twice even after immunity clears")
	observations.contact = {"health_after_single_rush": game.player.health, "rush_events": event_count("skull_rush"), "impact_events": event_count("skull_impact")}

func charge_distance_and_wall() -> void:
	setup()
	var skull := spawn()
	game.player.position = Vector3(0, 0, 4.3)
	skull.start_move()
	var origin: Vector3 = skull.position
	game.player.position = Vector3(2.5, 0, -1.5)
	check(is_equal_approx(skull.rush_distance, 3.6), "Unblocked skull charge retains its 3.6-unit travel budget")
	var max_distance := 0.0
	var all_walkable := true
	for i in range(65):
		step(1)
		max_distance = maxf(max_distance, skull.position.distance_to(origin))
		all_walkable = all_walkable and game.point_walkable(skull.position, skull.radius)
	# Existing contact/finish code stops on the last step rather than overshooting.
	check(max_distance >= 3.6 - 3.6 / 0.28 * STEP - 0.025 and max_distance <= 3.601, "Open charge covers its range within one existing movement step without overshoot")
	check(all_walkable and event_count("skull_impact") == 1, "Open charge stays on walkable ground and finishes once")
	observations.open_charge = {"budget": skull.rush_distance, "observed_distance": max_distance, "fixed_step_distance": 3.6 / 0.28 * STEP}
	setup()
	var bounds: Array = game.art.layout.bounds
	skull = spawn("skull", Vector3(0, 0, float(bounds[1]) + 1.7))
	game.player.position = Vector3(0, 0, float(bounds[1]) + 0.4)
	check(game.point_walkable(skull.position, skull.radius), "Wall test starts on actual room walkable ground")
	skull.start_move()
	origin = skull.position
	game.player.position = Vector3(2, 0, 1.5)
	var wall_budget: float = skull.rush_distance
	check(wall_budget > 0 and wall_budget < 3.6, "Actual room boundary shortens the committed rush path")
	all_walkable = true
	max_distance = 0
	for i in range(65):
		step(1)
		all_walkable = all_walkable and game.point_walkable(skull.position, skull.radius)
		max_distance = maxf(max_distance, skull.position.distance_to(origin))
	check(all_walkable and max_distance <= wall_budget + 0.001, "Wall-constrained rush never tunnels beyond the legal path")
	check(event_count("skull_impact") == 1 and game.player.health == 100, "Wall stop completes once without remote player damage")
	observations.wall_charge = {"budget": wall_budget, "distance": max_distance, "all_positions_walkable": all_walkable}

func interruption_pause_and_death() -> void:
	setup()
	var skull := spawn()
	skull.start_move()
	step(10)
	var warning: Node3D = skull.telegraph
	game.damage_enemy(skull, 1, Vector3.FORWARD, 0, "skull_test_interrupt")
	check(skull.state == "hurt" and (not is_instance_valid(warning) or not warning.visible), "Damage interrupts windup and immediately clears the warning")
	step(70)
	check(event_count("skull_rush") == 0 and game.player.health == 100, "Interrupted windup never releases a delayed rush")
	setup()
	skull = spawn()
	step(24)
	var before := visual_snapshot(skull)
	step(24)
	check(before != visual_snapshot(skull), "Skull hover and jaw actually animate during gameplay")
	skull.start_move()
	step(12)
	warning = skull.telegraph
	game.set_paused(true)
	before = visual_snapshot(skull)
	var warning_transform: Transform3D = warning.transform
	step(90)
	# Yield native frames too: catches accidental _process/TIME-based pose drift.
	for i in range(8): await process_frame
	check(before == visual_snapshot(skull), "Pause freezes body, jaw, flash and emissive pose across simulation and native frames")
	check(is_instance_valid(warning) and warning.visible and warning.transform == warning_transform and event_count("skull_rush") == 0, "Pause preserves the frozen warning without releasing an attack")
	game.set_paused(false)
	step(4)
	check(before != visual_snapshot(skull), "Resume advances the same suspended skull pose")
	game.damage_enemy(skull, 999, Vector3.FORWARD, 0, "skull_test_death")
	check(skull.dead and skull.state == "death" and skull.collision_layer == 0, "Lethal damage starts death and disables contact collision")
	check(not is_instance_valid(warning) or not warning.visible, "Death cancels any remaining warning")
	step(45)
	check(not is_instance_valid(skull) or not skull.visual.is_visible_in_tree(), "Dead skull is removed or hidden within the existing death lifecycle")
	check(event_count("skull_rush") == 0, "Death during windup cannot spawn a delayed rush")
	game._load_room(0)
	await process_frame
	check(not is_instance_valid(skull), "Room transition frees the dead skull instance")

func brute_regression() -> void:
	setup()
	var brute := spawn("brute", Vector3(0, 0, 0))
	check(brute.visual.get_script().resource_path == "res://scripts/demo01/visual.gd" and brute.visual.model.scene_file_path == "res://assets/characters/demo01/enemy.glb", "Brute retains the original authored rig and visual class")
	check(brute.visual.skeleton != null and brute.visual.anim != null and brute.visual.weapon != null, "Brute still has its skeleton, clips and club")
	game.enemy_ai = true
	brute.attack_cooldown = 0
	step(1)
	game.enemy_ai = false
	check(brute.state == "attack" and brute.visual.clip == "club_attack", "Brute AI still starts its authored club action")
	step(45)
	check(brute.attack_applied and game.player.health == 88, "Brute action still reaches contact and applies its existing damage")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Engine.physics_ticks_per_second = 60
	check(is_equal_approx(Engine.time_scale, 1.0), "Tests retain normal game time scale")
	for path in [MODEL, "res://scripts/gameplay/skull_visual.gd", "res://scripts/gameplay/enemy.gd", "res://scripts/demo01/enemy.gd", "res://shaders/skull_bone.gdshader"]:
		if FileAccess.file_exists(path): source_hashes[path] = FileAccess.get_sha256(path)
	check(ResourceLoader.exists(MODEL), "Authored skull model is loadable in this source or export")
	game = load("res://scenes/frontend/run.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	model_and_materials()
	charge_contact()
	charge_distance_and_wall()
	await interruption_pause_and_death()
	brute_regression()
	for path in source_hashes:
		check(source_hashes[path] == FileAccess.get_sha256(path), "Resource unchanged during test: " + path)
	var report := {"suite": "skull-r01", "success": failed.is_empty(), "passed": passed, "failed": failed,
		"simulation_fps": 60, "required_engine_argument": "--fixed-fps 60", "time_scale": Engine.time_scale,
		"method": "Production frontend/run scene, test_control and explicit advance(1/60); real AI, collision, health, material and pose state. No replacement runtime.",
		"source_hashes": source_hashes, "observations": observations,
		"limits": ["Geometry and shader state checks do not replace native camera/lighting visual acceptance.", "Eye sockets and nasal cavity are Cranium geometry; no separate Socket nodes are required."]}
	FileAccess.open(output.path_join("checks.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("SKULL_TESTS passed=", passed.size(), " failed=", failed.size())
	game.audio.shutdown()
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
