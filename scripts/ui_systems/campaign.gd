extends "res://scripts/gameplay/fx_campaign.gd"
## UI flow adapter. The original integrated scene and combat calculations stay intact.
signal pause_requested
var flow_view:Control
var dialogue_index:=0
var dialogue_seen:=false
var coins:=0
var reward_claimed:=false
var reward_claim_count:=0
var dialogue_body:Label
var modal_buttons:Array[Button]=[]

func _setup_world() -> void:
	super._setup_world()
	# Boon uses its own arrow/Enter handler; resume does not focus its preview hot areas.
	var canvas:Node=hud.get_parent()
	canvas.remove_child(hud)
	hud.queue_free()
	hud=preload("res://scripts/ui_systems/hud.gd").new()
	hud.arena=self
	canvas.add_child(hud)
	var layer:=CanvasLayer.new()
	layer.layer=25
	add_child(layer)
	flow_view=preload("res://scripts/frontend/view.gd").new()
	layer.add_child(flow_view)
	flow_view.hide()

func restart() -> void:
	dialogue_seen=false
	dialogue_index=0
	coins=0
	reward_claimed=false
	reward_claim_count=0
	if is_instance_valid(flow_view):flow_view.hide()
	super.restart()

func interact() -> void:
	if paused or transition_lock or not near_portal():return
	if phase=="entry" and not dialogue_seen:
		open_dialogue()
	elif phase=="cleared" and not reward_claimed:
		open_reward()
	else:super.interact()

func _set_phase(value:String,clock:=0.0) -> void:
	super._set_phase(value,clock)
	if is_instance_valid(hud):hud.visible=value not in ["dialogue","reward","boon"]

func open_dialogue() -> void:
	if phase!="entry" or dialogue_seen:return
	dialogue_index=0
	player.clear_input()
	_set_phase("dialogue")
	_freeze_animation(true)
	audio.set_suspended(true)
	flow_view.clear_view()
	flow_view.shade(.4)
	flow_view.picture("portrait-megaera-v03",Rect2(0,140,670,940))
	flow_view.picture("dialogue-paper-v01",Rect2(665,663,1080,333))
	flow_view.picture("nameplate-v01",Rect2(650,595,500,170))
	flow_view.label("墨纪拉",Rect2(757,666,320,55),38,Color("eee4d0"),"cn",true)
	flow_view.label("复仇女神",Rect2(777,713,275,35),20,Color("d69a61"),"cn",true)
	dialogue_body=flow_view.label("",Rect2(762,780,875,148),31,Color("272722"))
	dialogue_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	flow_view.button("继续  回车",Rect2(1410,907,266,66),advance_dialogue)
	flow_view.button("跳过",Rect2(1690,42,170,60),finish_dialogue)
	flow_view.show()
	flow_view.focus_first()
	update_dialogue()

func update_dialogue() -> void:
	dialogue_body.text=["前面是两波守卫。看清他们举起武器的时机，再从侧面进攻。","房间清空后，去光门领取祝福。能不能走到最后，就看你的本事了。"][dialogue_index]

func advance_dialogue() -> void:
	if phase!="dialogue":return
	if dialogue_index==0:
		dialogue_index=1
		update_dialogue()
	else:finish_dialogue()

func finish_dialogue() -> void:
	if phase!="dialogue":return
	dialogue_seen=true
	flow_view.hide()
	_set_phase("entry")
	audio.set_suspended(false)
	_freeze_animation(false)
	super.interact()

func open_reward() -> void:
	if phase!="cleared" or reward_claimed:return
	player.clear_input()
	_set_phase("reward")
	_freeze_animation(true)
	audio.set_suspended(true)
	flow_view.clear_view()
	flow_view.shade(.68)
	flow_view.picture("boon-header-v01",Rect2(385,220,1150,155))
	flow_view.label("房间已清空",Rect2(475,243,970,76),48,Color("e5dbc3"),"cn",true)
	flow_view.picture("icon-athena-v03",Rect2(855,406,210,200))
	flow_view.label("雅典娜的馈赠",Rect2(520,642,880,65),38,Color("e2d09e"),"cn",true)
	flow_view.label("冥币 +50  ·  选择一项祝福  ·  生命恢复 20",Rect2(510,725,900,55),27,Color("c6c9b7"),"cn",true)
	flow_view.button("领取馈赠",Rect2(705,826,510,88),claim_reward)
	flow_view.show()
	flow_view.focus_first()

func claim_reward() -> void:
	if phase!="reward" or reward_claimed:return
	reward_claimed=true
	reward_claim_count+=1
	coins+=50
	flow_view.hide()
	_set_phase("cleared")
	super.open_boon()

func advance(delta:float) -> void:
	if phase in ["dialogue","reward"]:return
	super.advance(delta)

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			pause_requested.emit()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode==KEY_R:return
	if phase in ["dialogue","reward"]:return
	super._unhandled_input(event)

func set_paused(value:bool) -> void:
	# Unlike the original preview, shell pause also works while a modal is open.
	paused=value
	player.clear_input()
	audio.set_suspended(value or phase in ["dialogue","reward","boon"])
	_freeze_animation(value or phase in ["dialogue","reward","boon"])
