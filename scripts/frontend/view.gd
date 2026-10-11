extends Control
## Shared 1920x1080 art composition. All ornament textures originate in restored PNGs.
const DESIGN=Vector2(1920,1080)
var stage:Control
var fonts:Dictionary={}
var registry:Dictionary={}
var texture_cache:Dictionary={}
var focus_buttons:Array[Button]=[]
var matte:ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for role in {"body":"AlegreyaSans-Regular.ttf","title":"AlegreyaSansSC-Bold.ttf","heading":"CrimsonText-Regular.ttf"}:
		fonts[role]=load("res://assets/ui/r02/fonts/"+{"body":"AlegreyaSans-Regular.ttf","title":"AlegreyaSansSC-Bold.ttf","heading":"CrimsonText-Regular.ttf"}[role])
	var chinese:=SystemFont.new()
	chinese.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	fonts["cn"]=chinese
	for file in ["res://assets/ui/integration/material-registry.json","res://assets/ui/r03/material-registry.json"]:
		if FileAccess.file_exists(file):
			for a in JSON.parse_string(FileAccess.get_file_as_string(file)).assets:registry[a.id]=a
	matte=ColorRect.new()
	matte.color=Color.TRANSPARENT
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	matte.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(matte)
	stage=Control.new()
	stage.size=DESIGN
	stage.clip_contents=true
	stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	resized.connect(fit)
	fit()

func fit() -> void:
	if not is_instance_valid(stage):return
	var ratio:float=minf(size.x/DESIGN.x,size.y/DESIGN.y)
	stage.scale=Vector2.ONE*ratio
	stage.position=(size-DESIGN*ratio)*.5

func clear_view() -> void:
	focus_buttons.clear()
	matte.color=Color.BLACK
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()

func shade(alpha:=.83) -> ColorRect:
	matte.color=Color(.005,.008,.009,alpha)
	# When a background is in the stage, also dim that background.
	if stage.get_child_count()>0:
		var n:=ColorRect.new()
		n.color=matte.color
		n.size=DESIGN
		n.mouse_filter=Control.MOUSE_FILTER_IGNORE
		stage.add_child(n)
	return matte

func texture(id:String) -> Texture2D:
	if texture_cache.has(id):return texture_cache[id]
	var a:Dictionary=registry[id]
	var t:Texture2D=load("res://"+str(a.rerender))
	var atlas:=AtlasTexture.new()
	atlas.atlas=t
	var b:Array=a.get("layoutBounds",a.contentBounds)
	atlas.region=Rect2(b[0],b[1],b[2],b[3])
	texture_cache[id]=atlas
	return atlas

func picture(id:String,rect:Rect2,parent:Control=null) -> TextureRect:
	var n:=TextureRect.new()
	n.texture=texture(id)
	n.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	n.position=rect.position
	n.size=rect.size
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	(parent if parent!=null else stage).add_child(n)
	return n

func raw_picture(path:String,rect:Rect2) -> TextureRect:
	var n:=TextureRect.new()
	n.texture=load(path)
	n.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	n.position=rect.position
	n.size=rect.size
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(n)
	return n

func label(value:String,rect:Rect2,pixels:=30,color:=Color("e8e1ce"),role:="cn",center:=false) -> Label:
	var n:=Label.new()
	n.text=value
	n.position=rect.position
	n.size=rect.size
	n.add_theme_font_override("font",fonts[role])
	n.add_theme_font_size_override("font_size",pixels)
	n.add_theme_color_override("font_color",color)
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if center:n.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(n)
	return n

func button(value:String,rect:Rect2,callback:Callable,plain:=false) -> Button:
	var n:=Button.new()
	n.text=value
	n.position=rect.position
	n.size=rect.size
	n.add_theme_font_override("font",fonts.cn)
	n.add_theme_font_size_override("font_size",30)
	n.add_theme_color_override("font_color",Color("e8e1ce"))
	n.add_theme_color_override("font_hover_color",Color("fff2a4"))
	n.add_theme_color_override("font_focus_color",Color("fff2a4"))
	for state in ["normal","hover","pressed","focus"]:
		if plain:
			var empty:=StyleBoxEmpty.new()
			n.add_theme_stylebox_override(state,empty)
		else:
			var box:=StyleBoxTexture.new()
			box.texture=texture("choice-normal-v06" if state=="normal" else "choice-focus-v03")
			n.add_theme_stylebox_override(state,box)
	if plain:
		n.alignment=HORIZONTAL_ALIGNMENT_LEFT
		n.add_theme_font_size_override("font_size",42)
	n.pressed.connect(callback)
	n.mouse_entered.connect(func():n.grab_focus())
	if plain:
		n.focus_entered.connect(func():n.text="›  "+value)
		n.focus_exited.connect(func():n.text=value)
	stage.add_child(n)
	focus_buttons.append(n)
	return n

func focus_first() -> void:
	if not focus_buttons.is_empty():focus_buttons[0].grab_focus()
	for i in range(focus_buttons.size()):
		focus_buttons[i].focus_neighbor_top=focus_buttons[(i-1+focus_buttons.size())%focus_buttons.size()].get_path()
		focus_buttons[i].focus_neighbor_bottom=focus_buttons[(i+1)%focus_buttons.size()].get_path()
