extends "res://scripts/ui_boon_r02.gd"
## Runtime Chinese composition. The source-alignment preview stays in English.
const BOON_NAMES=["利刃","坚毅之心","疾步"]
const DESCRIPTIONS=["武器攻击与新星造成的伤害提高。","提高最大生命，并立即恢复25点生命。","更快恢复冲刺，灵活闪避敌人的攻击。"]
const VALUES=["伤害加成  +30%","最大生命  +25","冲刺冷却  -25%   0.62秒 → 0.465秒"]
const TIPS=[
	"武器攻击与新星伤害提高30%。\n包含冲刺攻击。",
	"最大生命增加25点，\n并立即恢复25点生命。",
	"冲刺冷却缩短25%。\n冷却时间：0.62秒 → 0.465秒。"
]
const INPUT_HINT="↑ / ↓ 切换    回车 / 空格确认    鼠标点击选择"
var chinese_font:SystemFont
var chinese_bold:SystemFont
var localized_labels:Array[Label]=[]
var localized_ready:=false

func _ready() -> void:
	registry_path="res://assets/ui/integration/material-registry.json"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var backdrop:=ColorRect.new()
	backdrop.color=Color("050909")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	super._ready()
	# Replace the preview text as complete Chinese blocks, not spaced English glyphs.
	for node in stage.get_children():
		if node is Label:
			stage.remove_child(node)
			node.queue_free()
	chinese_font=SystemFont.new()
	chinese_font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	chinese_bold=SystemFont.new()
	chinese_bold.font_names=chinese_font.font_names
	chinese_bold.font_weight=700
	_zh_label("雅典娜的祝福",Rect2(605,35,870,91),58,Color("eee9db"),true,true)
	_zh_label("选择一份馈赠，继续你的试炼",Rect2(695,126,730,34),23,Color("c5c497"),false,true)
	_zh_label("选择一项祝福",Rect2(564,207,650,58),34)
	for i in range(3):
		_zh_label(BOON_NAMES[i],Rect2(782,ROW_Y[i]+29,662,55),37,Color("eeece1"),true)
		_zh_label(DESCRIPTIONS[i],Rect2(782,ROW_Y[i]+92,662,49),28,Color("d1d2cb"))
		_zh_label(VALUES[i],Rect2(782,ROW_Y[i]+150,662,46),27,Color("91cf60"),true)
	tip_title=_zh_label("",Rect2(1545,320,390,46),30,Color("eeece1"),true)
	tip_body=_zh_label("",Rect2(1545,376,390,84),24,Color("d1d2cb"))
	tip_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_zh_label("本局馈赠",Rect2(1545,497,390,46),30,Color("eeece1"),true)
	var rules:=_zh_label("选择后额外恢复20点生命。\n祝福本局有效，重开后清空。",Rect2(1545,553,390,84),24,Color("d1d2cb"))
	rules.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status=_zh_label(INPUT_HINT,Rect2(560,1038,1425,57),25,Color("d6ceb4"),false,true)
	localized_ready=true
	set_focus_index(0)

func _zh_label(value:String,rect:Rect2,pixels:int,color:=Color("e9e9e3"),bold:=false,center:=false) -> Label:
	var node:=Label.new()
	node.text=value
	node.position=rect.position
	node.size=rect.size
	node.add_theme_font_override("font",chinese_bold if bold else chinese_font)
	node.add_theme_font_size_override("font_size",pixels)
	node.add_theme_color_override("font_color",color)
	node.add_theme_constant_override("line_spacing",5)
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	if center:node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(node)
	localized_labels.append(node)
	return node

func _png_texture(path:String) -> ImageTexture:
	var source:Texture2D=load(path)
	assert(source!=null,"Missing packaged UI texture: "+path)
	var image:Image=source.get_image()
	if image.is_compressed():image.decompress()
	return ImageTexture.create_from_image(image)

func set_focus_index(index:int) -> void:
	super.set_focus_index(index)
	if not localized_ready:return
	tip_title.text=BOON_NAMES[focus_index]
	tip_body.text=TIPS[focus_index]

func reset_choice() -> void:
	super.reset_choice()
	if localized_ready:status.text=INPUT_HINT

func confirm_choice(index:int) -> void:
	super.confirm_choice(index)
	if localized_ready and selected_index>=0:status.text="已获得祝福："+BOON_NAMES[selected_index]

func _unhandled_key_input(event:InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:return
	match event.keycode:
		KEY_UP: set_focus_index(focus_index-1)
		KEY_DOWN: set_focus_index(focus_index+1)
		KEY_ENTER,KEY_SPACE: confirm_choice(focus_index)
		_:return
	get_viewport().set_input_as_handled()
