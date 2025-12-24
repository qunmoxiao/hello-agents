# 场景指南UI脚本
extends CanvasLayer

@onready var control: Control = $Control
@onready var panel: Panel = $Control/Panel
@onready var title_label: Label = $Control/Panel/TitleLabel
@onready var scroll_container: ScrollContainer = $Control/Panel/ScrollContainer
@onready var content_container: VBoxContainer = $Control/Panel/ScrollContainer/ContentContainer
@onready var close_button: Button = $Control/Panel/CloseButton
@onready var hint_label: Label = $Control/Panel/HintLabel

func _ready():
	add_to_group("scene_guide_ui")
	visible = false
	
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	_setup_ui_style()
	print("[INFO] 场景指南UI已初始化")

var current_chapter: int = 1  # 当前章节，用于动态调整风格

func _setup_ui_style():
	"""设置UI样式"""
	# 设置全屏背景
	if control:
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 设置面板样式（增大尺寸，适合青少年）
	if panel:
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.custom_minimum_size = Vector2(2000, 1400)  # 从800x600增大到1200x900
		panel.offset_left = -1000
		panel.offset_top = -700
		panel.offset_right = 1000
		panel.offset_bottom = 700
		
		# 默认样式（会在update_guide_content中根据章节更新）
		_update_panel_style()
	
	# 设置标题样式（增大字体）
	if title_label:
		title_label.add_theme_font_size_override("font_size", 60)  # 从44增大到60
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 设置关闭按钮样式（增大字体）
	if close_button:
		close_button.add_theme_font_size_override("font_size", 36)  # 从28增大到36
		close_button.text = "关闭 (B/ESC)"
	
	# 设置提示标签样式（增大字体）
	if hint_label:
		hint_label.add_theme_font_size_override("font_size", 32)  # 从24增大到32
		hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.text = "按B键或ESC键关闭"

func _update_panel_style():
	"""根据当前章节更新面板样式"""
	if not panel:
		return
	
	var style_box = StyleBoxFlat.new()
	
	# 根据章节设置不同风格
	match current_chapter:
		1:  # 第一章：蜀中 - 古朴、自然、绿色调
			style_box.bg_color = Color(0.12, 0.2, 0.15, 0.96)  # 深绿色背景
			style_box.border_color = Color(0.5, 0.8, 0.6, 1.0)  # 浅绿色边框
			style_box.border_width_left = 6
			style_box.border_width_top = 6
			style_box.border_width_right = 6
			style_box.border_width_bottom = 6
			style_box.corner_radius_top_left = 20
			style_box.corner_radius_top_right = 20
			style_box.corner_radius_bottom_left = 20
			style_box.corner_radius_bottom_right = 20
			style_box.shadow_color = Color(0.0, 0.2, 0.1, 0.6)
			style_box.shadow_size = 10
			style_box.shadow_offset = Vector2(0, 5)
		2:  # 第二章：长安 - 华丽、金色、红色调
			style_box.bg_color = Color(0.25, 0.18, 0.12, 0.96)  # 深金色背景
			style_box.border_color = Color(1.0, 0.85, 0.4, 1.0)  # 金色边框
			style_box.border_width_left = 8
			style_box.border_width_top = 8
			style_box.border_width_right = 8
			style_box.border_width_bottom = 8
			style_box.corner_radius_top_left = 25
			style_box.corner_radius_top_right = 25
			style_box.corner_radius_bottom_left = 25
			style_box.corner_radius_bottom_right = 25
			style_box.shadow_color = Color(0.8, 0.6, 0.2, 0.7)
			style_box.shadow_size = 12
			style_box.shadow_offset = Vector2(0, 6)
		3:  # 第三章：流放 - 沧桑、深色、棕色调
			style_box.bg_color = Color(0.15, 0.12, 0.1, 0.96)  # 深棕色背景
			style_box.border_color = Color(0.7, 0.6, 0.5, 1.0)  # 浅棕色边框
			style_box.border_width_left = 6
			style_box.border_width_top = 6
			style_box.border_width_right = 6
			style_box.border_width_bottom = 6
			style_box.corner_radius_top_left = 18
			style_box.corner_radius_top_right = 18
			style_box.corner_radius_bottom_left = 18
			style_box.corner_radius_bottom_right = 18
			style_box.shadow_color = Color(0.1, 0.05, 0.0, 0.7)
			style_box.shadow_size = 10
			style_box.shadow_offset = Vector2(0, 5)
		_:  # 默认样式
			style_box.bg_color = Color(0.15, 0.18, 0.25, 0.96)
			style_box.border_color = Color(0.9, 0.75, 0.4, 1.0)
			style_box.border_width_left = 5
			style_box.border_width_top = 5
			style_box.border_width_right = 5
			style_box.border_width_bottom = 5
			style_box.corner_radius_top_left = 15
			style_box.corner_radius_top_right = 15
			style_box.corner_radius_bottom_left = 15
			style_box.corner_radius_bottom_right = 15
			style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
			style_box.shadow_size = 8
			style_box.shadow_offset = Vector2(0, 4)
	
	panel.add_theme_stylebox_override("panel", style_box)

func _input(event: InputEvent):
	"""处理输入事件"""
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		close_guide()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_guide") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B):
		close_guide()
		get_viewport().set_input_as_handled()

func update_guide_content(chapter_data: Dictionary):
	"""更新指南内容"""
	if not content_container:
		return
	
	# 更新当前章节
	current_chapter = chapter_data.get("chapter", 1)
	
	# 更新面板样式（根据章节）
	_update_panel_style()
	
	# 更新标题样式（根据章节）
	if title_label:
		if chapter_data.has("title"):
			title_label.text = "场景指南 - " + chapter_data["title"]
		# 根据章节调整标题颜色
		match current_chapter:
			1:  # 蜀中 - 绿色调
				title_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7, 1.0))
			2:  # 长安 - 金色调
				title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
			3:  # 流放 - 棕色调
				title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.6, 1.0))
			_:
				title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	
	# 清空现有内容
	for child in content_container.get_children():
		child.queue_free()
	
	# 创建场景介绍部分
	_create_section("场景介绍", chapter_data.get("scene_intro", ""))
	
	# 创建李白近况部分
	_create_section("李白近况", chapter_data.get("libai_status", ""))

func _create_section(title: String, content: String):
	"""创建指南部分"""
	if content.is_empty():
		return
	
	# 创建部分容器
	var section_container = VBoxContainer.new()
	section_container.add_theme_constant_override("separation", 15)  # 增大间距
	section_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 创建标题（增大字体）
	var section_title = Label.new()
	section_title.text = "【" + title + "】"
	section_title.add_theme_font_size_override("font_size", 48)  # 从36增大到48
	
	# 根据章节调整标题颜色
	match current_chapter:
		1:  # 蜀中 - 绿色调
			section_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7, 1.0))
		2:  # 长安 - 金色调
			section_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
		3:  # 流放 - 棕色调
			section_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.65, 1.0))
		_:
			section_title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0, 1.0))
	
	section_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section_container.add_child(section_title)
	
	# 创建内容（增大字体）
	var section_content = RichTextLabel.new()
	section_content.bbcode_enabled = true
	section_content.text = content
	# ⭐ RichTextLabel需要使用normal_font_size而不是font_size
	section_content.add_theme_font_size_override("normal_font_size", 38)  # 从28增大到38
	
	# 根据章节调整内容颜色
	match current_chapter:
		1:  # 蜀中 - 浅绿色调
			section_content.add_theme_color_override("default_color", Color(0.95, 1.0, 0.95, 1.0))
		2:  # 长安 - 浅金色调
			section_content.add_theme_color_override("default_color", Color(1.0, 0.98, 0.9, 1.0))
		3:  # 流放 - 浅棕色调
			section_content.add_theme_color_override("default_color", Color(0.95, 0.92, 0.88, 1.0))
		_:
			section_content.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9, 1.0))
	
	section_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section_content.fit_content = true
	section_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section_container.add_child(section_content)
	
	# 添加间距（增大）
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)  # 从20增大到30
	section_container.add_child(spacer)
	
	content_container.add_child(section_container)

func close_guide():
	"""关闭指南"""
	visible = false

func _on_close_button_pressed():
	"""关闭按钮点击"""
	close_guide()

