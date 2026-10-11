extends "res://scripts/demo01/fx_base.gd"
## First demo's thirteen effects; mature painted sweep reused for both sword cuts.
const DemoRules = preload("res://scripts/demo01/rules.gd")

func attack(pos: Vector3, direction: Vector3, action: String) -> void:
	if action not in DemoRules.ACTIONS: return
	if action == "slash_2":
		var forward := direction.normalized()
		if forward.is_zero_approx(): forward = Vector3.FORWARD
		var key := "demo01-reverse-sweep"
		if not mesh_cache.has(key): _cached(key,SlashMesh.build(2.12))
		var sweep := _spawn(mesh_cache[key],WHITE,pos+forward*0.18+Vector3.UP*0.75,0.23)
		sweep.rotation.y = atan2(forward.x,forward.z)
		sweep.scale.x = -1.0
		var material := ShaderMaterial.new()
		material.shader = SlashShader
		sweep.material_override = material
		effects[-1].mode = "painted_slash"
	elif action in ["thrust","dash_strike"]:
		var forward := direction.normalized()
		var origin := pos+Vector3.UP*.85
		var reach := float(DemoRules.ACTIONS[action].reach)
		_line(origin,origin+forward*reach,.15,WHITE,.13)
		var side := Vector3(forward.z,0,-forward.x)
		for sign_value in [-1,1]:
			_line(origin+side*.16*sign_value,origin+forward*reach*.94+side*.04*sign_value,.055,GOLD,.19)
		if action == "dash_strike": _line(origin-forward*1.2,origin,.11,Color("ff713e"),.16)
	else:
		super.attack(pos,direction,action)

func dash_burst(pos: Vector3, direction: Vector3) -> void:
	burst(pos+Vector3.UP*.2,-direction,10,Color("fa682f"),2.8)
	for i in range(3):
		var offset := Vector3(0,.35+i*.31,0)
		_line(pos+offset-direction*1.5,pos+offset+direction*.25,.022,Color("ffb66a"),.17)

func afterimage(visual: ActorVisual, _color: Color) -> void:
	if DisplayServer.get_name() == "headless": return
	super.afterimage(visual,Color(1.0,.24,.08,.23))

func death(pos: Vector3) -> void:
	# The original brute breaks into a dark upward silhouette with short debris.
	# Keep it separate from the hero's red death effect.
	for i in range(14):
		var velocity := Vector3(rng.randf_range(-1.3,1.3),rng.randf_range(1.3,3.1),rng.randf_range(-1.3,1.3))
		var shard := _spawn(shard_mesh,Color("1c1029"),pos+Vector3(rng.randf_range(-.3,.3),rng.randf_range(.5,1.5),rng.randf_range(-.3,.3)),.35+rng.randf()*.25,0,velocity)
		shard.material_override = glow(Color("1c1029"),false)
		shard.scale = Vector3(.5,1.4+rng.randf(),.5)
		effects[-1].gravity = 2.0
		shard.rotation = velocity
	burst(pos+Vector3.UP*.8,Vector3.UP,8,Color("e89559"),2.3)

func hurt(pos: Vector3, lethal := false) -> void:
	burst(pos+Vector3.UP,Vector3.UP,22 if lethal else 9,Color("e32c3f"),3.0)
	if lethal:
		var stain := _spawn(ring(1.3,1.3),Color(0.38,0.012,0.025,0.8),pos+Vector3.UP*.03,1.8)
		stain.material_override = glow(Color(0.38,0.012,0.025,0.8),false)
		_expand(pos,1.7,Color("d42739"),.24)

func tick(delta: float, combat_frozen := false) -> void:
	# Freeze sword/contact imagery with the same hit-stop as the bodies.
	if combat_frozen: return
	super.tick(delta,false)
