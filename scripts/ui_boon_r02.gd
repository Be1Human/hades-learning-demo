extends Control
## R02 reference-alignment preview only; no combat state is mutated.
signal boon_selected(index: int)
@export var registry_path:="res://docs/ui/material-registry.json"

const DESIGN := Vector2(2048, 1152)
const ROW_Y := [281.0, 519.0, 754.0]
var focus_index: int = 0
var selected_index: int = -1
var confirmation_count: int = 0
var registry: Dictionary = {}
var textures: Dictionary = {}
var stage: Control
var row_frames: Array[TextureRect] = []
var buttons: Array[Button] = []
var tip_title: Label
var tip_body: Label
var status: Label
var fonts: Dictionary = {}
var refinement: Dictionary = {}

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(registry_path))
	for item in data.assets:
		registry[item.id] = item
	refinement = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/r02/boon-refinement.json"))
	for role in refinement.fonts:
		var font := load("res://" + refinement.fonts[role]) as FontFile
		fonts[role] = font
	stage = Control.new()
	stage.size = DESIGN
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var bg := TextureRect.new()
	bg.texture = _png_texture("res://assets/ui/r02/raster/boon-backdrop-v01.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = DESIGN
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	var panel := _asset("boon-panel-v01", Rect2(450, 173, 1155, 850))
	panel.modulate = Color(.72, .72, .72)
	for y in ROW_Y:
		row_frames.append(_asset("choice-normal-v06", Rect2(550, y, 939, 228)))
	_asset("boon-header-v01", Rect2(285, 18, 1590, 192))
	var rays := _asset(refinement.rays.id, _rect(refinement.rays.rect))
	rays.modulate.a = refinement.rays.opacity
	var portrait := _asset(refinement.portrait.id, _rect(refinement.portrait.rect))
	var brightness: float = refinement.portrait.brightness
	portrait.modulate = Color(brightness, brightness, brightness)
	_asset("icon-athena-v03", Rect2(99, 82, 185, 173))
	_asset("tooltip-v01", Rect2(1512, 307, 457, 176))
	_asset("tooltip-v01", Rect2(1512, 483, 457, 176))
	var heading_x: float = 597
	for glyph in "BOONS OF ATHENA":
		_label(glyph, Vector2(heading_x, 56), 46, Color("e9e9e3"), "heading")
		heading_x += fonts.heading.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x + 32.5
	_label("DIVINE PROTECTION AND UNCONQUERABLE STRENGTH.", Vector2(802, 131), 19, Color("c5c497"))
	_label("Choose One:", Vector2(561, 214), 42, Color("e9e9e3"), "title").scale.x = .97
	var names := ["Divine Strike", "Phalanx Shot", "Divine Dash"]
	var desc := [["Your ", "Attack", " is stronger, and can ", "Deflect."], ["Your ", "Cast", " damages foes in a small area, and can ", "Deflect."], ["Your ", "Dash", " deals damage, and can ", "Deflect."]]
	var stats := ["Attack Damage:", "Cast Damage:", "Dash Damage:"]
	var values := ["+40%", "50 ➜ 85", "10"]
	var icons := ["boon-athena-attack-v01", "boon-athena-cast-v01", "boon-athena-dash-v01"]
	for i in range(3):
		var y: float = ROW_Y[i]
		_asset(icons[i], Rect2(565, y + 25, 184, 185))
		_label(names[i], Vector2(769, y + [35,32,31][i]), 38, Color("e9e9e3"), "title").scale.x = .97
		var cursor_x: float = 769
		for segment in range(4):
			var role: String = "bold" if segment % 2 else "body"
			_label(desc[i][segment], Vector2(cursor_x, y + 83), 27, Color("e9e9e3") if segment % 2 else Color("cfcfcc"), role)
			cursor_x += fonts[role].get_string_size(desc[i][segment], HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x
		_label("›", Vector2(768, y + 117), 27, Color("cfcfcc"))
		_label(stats[i], Vector2(786, y + 117), 27, Color("cfcfcc"))
		if i == 1:
			_label("50", Vector2(1190, y + 120), 27, Color("81909c"), "bold")
			_label("➜", Vector2(1224, y + 120), 27, Color("e9e9e3"), "bold")
			_label("85", Vector2(1250, y + 120), 27, Color("83cb4d"), "value")
		else:
			_label(values[i], Vector2(1190, y + 120), 27, Color("83cb4d"), "value")
		var button := Button.new()
		button.position = Vector2(550, y)
		button.size = Vector2(939, 228)
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		for mode in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(mode, StyleBoxEmpty.new())
		button.mouse_entered.connect(func(): set_focus_index(i))
		button.pressed.connect(func(): confirm_choice(i))
		stage.add_child(button)
		buttons.append(button)
	tip_title = _label("Attack", Vector2(1544, 329), 32, Color("e9e9e3"), "tooltip")
	tip_body = _label("Press or hold ⓧ to use your main weapon.", Vector2(1544, 369), 25, Color("cfcfcc"))
	_label("Deflect", Vector2(1544, 505), 32, Color("e9e9e3"), "tooltip")
	_label("Turn foes’ attacks back against them.", Vector2(1544, 542), 25, Color("cfcfcc"))
	status = _label("", Vector2(800, 1070), 24)
	resized.connect(_fit)
	_fit()
	set_focus_index(0)

func _fit() -> void:
	var factor: float = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	stage.scale = Vector2.ONE * factor
	stage.position = (size - DESIGN * factor) / 2.0

func _texture(id: String) -> AtlasTexture:
	if textures.has(id):
		return textures[id]
	var item: Dictionary = registry[id]
	assert(item.svgReview.status == "approved", "Unreviewed R02 asset: " + id)
	var atlas := AtlasTexture.new()
	atlas.atlas = _png_texture("res://" + item.rerender)
	var b: Array = item.get("layoutBounds", item.contentBounds)
	atlas.region = Rect2(b[0], b[1], b[2], b[3])
	textures[id] = atlas
	return atlas

func _png_texture(path: String) -> ImageTexture:
	# This isolated local review scene reads pipeline outputs without importing
	# every high-resolution master. Export integration is a later task.
	var image := Image.new()
	var result := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	assert(result == OK, "PNG load failed: " + path)
	return ImageTexture.create_from_image(image)

func _asset(id: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = _texture(id)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(node)
	return node

func _rect(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])

func _label(value: String, point: Vector2, font_size: int, color := Color("e9e9e3"), role: String = "body") -> Label:
	var label := Label.new()
	label.text = value
	label.position = point + Vector2(0, (font_size - fonts[role].get_height(font_size)) / 2.0)
	label.add_theme_font_override("font", fonts[role])
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(label)
	return label

func set_focus_index(index: int) -> void:
	if selected_index >= 0:
		return
	focus_index = posmod(index, 3)
	for i in range(3):
		row_frames[i].texture = _texture("choice-focus-v03" if i == focus_index else "choice-normal-v06")
	tip_title.text = ["Attack", "Cast", "Dash"][focus_index]
	tip_body.text = ["Press or hold ⓧ to use your main weapon.", "Press Ⓑ to launch your Cast.", "Press Ⓐ to dash a short distance."][focus_index]

func confirm_choice(index: int) -> void:
	if selected_index >= 0:
		return
	set_focus_index(index)
	selected_index = focus_index
	confirmation_count += 1
	for button in buttons:
		button.disabled = true
	status.text = "Selected: " + ["Divine Strike", "Phalanx Shot", "Divine Dash"][selected_index] + "    [R] Reset"
	boon_selected.emit(selected_index)

func reset_choice() -> void:
	selected_index = -1
	confirmation_count = 0
	for button in buttons:
		button.disabled = false
	status.text = ""
	set_focus_index(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_UP: set_focus_index(focus_index - 1)
		KEY_DOWN: set_focus_index(focus_index + 1)
		KEY_ENTER, KEY_SPACE: confirm_choice(focus_index)
		KEY_R: reset_choice()
