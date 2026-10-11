extends "res://scripts/environment/tartarus_preview.gd"
## Native environment gallery; separate from the combat controller.
@export_range(0,2) var initial_room:=0
const ROOMS=[preload("res://scripts/environment/tartarus_entry_room.gd"),preload("res://scripts/environment/tartarus_reference_room.gd"),preload("res://scripts/environment/tartarus_colonnade_room.gd")]
const TITLES=["01  冥门前厅","02  双火池战斗厅","03  守卫柱廊"]
var room_index:=0
var room_title:Label
var buttons:Array[Button]=[]
var ui:CanvasLayer
var portal_light:OmniLight3D

func _ready() -> void:
	super._ready()
	for child in get_children():
		if child is CanvasLayer:child.queue_free()
	portal_light=OmniLight3D.new()
	portal_light.position=Vector3(0,3.5,-1.8)
	portal_light.light_color=Color("ecd1a0")
	portal_light.light_energy=1.6
	portal_light.omni_range=7.5
	add_child(portal_light)
	_build_ui()
	select_room(initial_room)

func _build_ui() -> void:
	ui=CanvasLayer.new()
	ui.name="RoomNavigation"
	add_child(ui)
	var panel:=PanelContainer.new()
	panel.position=Vector2(24,22)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("10191beb")
	style.border_color=Color("716346")
	style.set_border_width_all(1)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=14
	style.content_margin_bottom=14
	panel.add_theme_stylebox_override("panel",style)
	ui.add_child(panel)
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",10)
	panel.add_child(stack)
	room_title=Label.new()
	room_title.add_theme_font_size_override("font_size",24)
	room_title.add_theme_color_override("font_color",Color("dfcca3"))
	stack.add_child(room_title)
	var row:=HBoxContainer.new()
	stack.add_child(row)
	for i in range(3):
		var button:=Button.new()
		button.text=TITLES[i]
		button.toggle_mode=true
		button.pressed.connect(select_room.bind(i))
		row.add_child(button)
		buttons.append(button)
	var hint:=Label.new()
	hint.text="1 / 2 / 3 切换房间 · 拖动旋转 · 滚轮缩放 · R 重置 · T 俯视\n环境预览 · 战斗请运行 Launch-Demo01.cmd"
	hint.add_theme_color_override("font_color",Color("9daaa3"))
	stack.add_child(hint)

func select_room(index:int) -> void:
	if index<0 or index>=ROOMS.size():return
	if is_instance_valid(room):
		remove_child(room)
		room.queue_free()
	room_index=index
	room=ROOMS[index].new()
	add_child(room)
	room.build()
	if is_instance_valid(portal_light):portal_light.visible=index!=1
	_reset_view()
	if is_instance_valid(room_title):room_title.text=TITLES[index]+"  /  塔尔塔罗斯"
	for i in range(buttons.size()):buttons[i].set_pressed_no_signal(i==index)

func _reset_view() -> void:
	azimuth=-.785398
	elevation=.60 if room_index!=1 else .52
	view_size=15.3 if room_index!=1 else 10.4
	camera_focus=Vector3(0,.85,.35) if room_index!=1 else Vector3(-1.09,0,-.816)
	_update_camera()

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
			select_room(event.physical_keycode-KEY_1)
			return
		if event.physical_keycode==KEY_R:
			_reset_view()
			return
	super._unhandled_input(event)
