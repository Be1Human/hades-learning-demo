class_name AudioBank
extends Node
## Authored sample layers with bounded voices; hit-stop never freezes audio.
const BANK_PATH := "res://assets/audio/bank.json"
const POOL_SIZE := 24
const CATEGORY_BUSES := ["Combat", "Foley", "Cues", "UI", "Ambience"]

var streams: Dictionary = {}
var profiles: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var last_variant: Dictionary = {}
var last_played: Dictionary = {}
var rng := RandomNumberGenerator.new()
var ambience: AudioStreamPlayer
var muted := false
var suspended := false
var duck_left := 0.0
var ambience_gain := -27.0
var event_log: Array[Dictionary] = []
var closed := false

func _ready() -> void:
	rng.randomize()
	_setup_buses()
	muted = AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))
	if not FileAccess.file_exists(BANK_PATH):
		push_error("Missing audio bank. Run python tools/make_audio.py")
		return
	profiles = JSON.parse_string(FileAccess.get_file_as_string(BANK_PATH))["cues"]
	for clip: String in profiles:
		var variants: Array[AudioStream] = []
		for path: String in profiles[clip]["files"]:
			if ResourceLoader.exists(path): variants.append(load(path))
		streams[clip] = variants
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	ambience = AudioStreamPlayer.new()
	ambience.bus = "Ambience"
	ambience.volume_db = ambience_gain
	add_child(ambience)
	var bed := load("res://assets/audio/ambience.wav") as AudioStreamWAV
	bed = bed.duplicate()
	bed.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bed.loop_begin = 0
	bed.loop_end = bed.data.size() / (4 if bed.stereo else 2)
	ambience.stream = bed

func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, "SFX")
		AudioServer.set_bus_send(index, "Master")
		var compressor := AudioEffectCompressor.new()
		compressor.threshold = -12.0
		compressor.ratio = 2.5
		compressor.attack_us = 2000.0
		compressor.release_ms = 100.0
		AudioServer.add_bus_effect(index, compressor)
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(index, limiter)
	for category: String in CATEGORY_BUSES:
		if AudioServer.get_bus_index(category) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, category)
			AudioServer.set_bus_send(index, "SFX")

func start_ambience() -> void:
	if not closed and is_instance_valid(ambience) and not ambience.playing: ambience.play()

func _process(delta: float) -> void:
	duck_left = maxf(0.0, duck_left - delta)
	if is_instance_valid(ambience):
		var target := -34.0 if duck_left > 0.0 else -27.0
		ambience_gain = move_toward(ambience_gain, target, delta * (90.0 if duck_left > 0.0 else 15.0))
		ambience.volume_db = ambience_gain

func play(clip: String, volume := 0.0, pitch := 1.0) -> bool:
	if closed or not streams.has(clip) or streams[clip].is_empty(): return false
	var spec: Dictionary = profiles[clip]
	if suspended and spec.bus != "UI": return false
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(clip, -100000)) < int(spec.cooldown_ms): return false
	var count := 0
	var chosen: AudioStreamPlayer
	var victim: AudioStreamPlayer
	for p in players:
		if not p.playing:
			if chosen == null: chosen = p
			continue
		if p.get_meta("clip", "") == clip: count += 1
		# Only strictly more important cues may evict an active voice.
		if int(p.get_meta("priority", 0)) < int(spec.priority):
			if victim == null or int(p.get_meta("priority")) < int(victim.get_meta("priority")): victim = p
	if count >= int(spec.max_voices): return false
	if chosen == null: chosen = victim
	if chosen == null: return false
	var variants: Array = streams[clip]
	var index := rng.randi_range(0, variants.size() - 1)
	if variants.size() > 1 and index == int(last_variant.get(clip, -1)):
		index = (index + rng.randi_range(1, variants.size() - 1)) % variants.size()
	last_variant[clip] = index
	last_played[clip] = now
	chosen.stop()
	chosen.stream = variants[index]
	chosen.bus = spec.bus
	chosen.volume_db = float(spec.gain_db) + volume + rng.randf_range(-0.6, 0.6)
	chosen.pitch_scale = clampf(pitch * rng.randf_range(1.0 - float(spec.pitch_jitter), 1.0 + float(spec.pitch_jitter)), 0.5, 2.0)
	chosen.stream_paused = false
	chosen.set_meta("clip", clip)
	chosen.set_meta("priority", spec.priority)
	chosen.play()
	if int(spec.priority) >= 70: duck_left = maxf(duck_left, 0.3)
	event_log.append({"clip":clip, "variant":index, "bus":spec.bus, "time_ms":now})
	if event_log.size() > 128: event_log.pop_front()
	return true

func stop_cue(clip: String) -> void:
	for p in players:
		if p.get_meta("clip", "") == clip: p.stop()

func set_suspended(value: bool) -> void:
	suspended = value
	for p in players:
		if p.bus != "UI": p.stream_paused = value
	if is_instance_valid(ambience): ambience.stream_paused = value

func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), value)

func reset_mix() -> void:
	for p in players:
		p.stop()
		p.stream_paused = false
	last_played.clear()
	duck_left = 0.0
	set_suspended(false)

func shutdown() -> void:
	closed = true
	reset_mix()
	for p in players: p.stream = null
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream = null
	streams.clear()

func _exit_tree() -> void:
	shutdown()
