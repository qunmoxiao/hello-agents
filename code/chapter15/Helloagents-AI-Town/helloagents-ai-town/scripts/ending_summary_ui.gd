# 结尾总结UI脚本
# 显示整个游戏的剧本总结
extends CanvasLayer

@onready var control: Control = $Control
@onready var panel: Panel = $Control/Panel
@onready var title_label: Label = $Control/Panel/TitleLabel
@onready var subtitle_label: Label = $Control/Panel/SubtitleLabel
@onready var scroll_container: ScrollContainer = $Control/Panel/ScrollContainer
@onready var content_container: VBoxContainer = $Control/Panel/ScrollContainer/ContentContainer
@onready var close_button: Button = $Control/Panel/CloseButton
@onready var hint_label: Label = $Control/Panel/HintLabel

var summary_data: Dictionary = {}

func _ready():
	add_to_group("ending_summary_ui")
	visible = false
	
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	_setup_ui_style()
	_load_summary_data()
	print("[INFO] 结尾总结UI已初始化")

func _setup_ui_style():
	"""设置UI样式 - 庄重、有仪式感的结尾风格"""
	# 设置全屏背景（深色半透明）
	if control:
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 添加深色背景色（如果不存在）
		if not control.has_node("BackgroundColorRect"):
			var bg_color_rect = ColorRect.new()
			bg_color_rect.name = "BackgroundColorRect"
			bg_color_rect.color = Color(0.05, 0.05, 0.08, 0.95)  # 深色背景
			bg_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			control.add_child(bg_color_rect)
			control.move_child(bg_color_rect, 0)  # 移到最底层
	
	# 设置面板样式（更大，更庄重）
	if panel:
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.custom_minimum_size = Vector2(2200, 1500)  # 更大的尺寸
		panel.offset_left = -1100
		panel.offset_top = -750
		panel.offset_right = 1100
		panel.offset_bottom = 750
		
		# 庄重的深色风格，金色边框
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.1, 0.08, 0.12, 0.98)  # 深紫色背景
		style_box.border_color = Color(1.0, 0.85, 0.3, 1.0)  # 金色边框
		style_box.border_width_left = 8
		style_box.border_width_top = 8
		style_box.border_width_right = 8
		style_box.border_width_bottom = 8
		style_box.corner_radius_top_left = 20
		style_box.corner_radius_top_right = 20
		style_box.corner_radius_bottom_left = 20
		style_box.corner_radius_bottom_right = 20
		style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
		style_box.shadow_size = 20
		style_box.shadow_offset = Vector2(0, 8)
		panel.add_theme_stylebox_override("panel", style_box)
	
	# 设置主标题样式（更大，金色）
	if title_label:
		title_label.add_theme_font_size_override("font_size", 80)  # 大字体
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))  # 金色
		title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
		title_label.add_theme_constant_override("shadow_offset_x", 4)
		title_label.add_theme_constant_override("shadow_offset_y", 4)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.text = "《李白的一生》"
	
	# 设置副标题样式
	if subtitle_label:
		subtitle_label.add_theme_font_size_override("font_size", 48)
		subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6, 1.0))  # 浅金色
		subtitle_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
		subtitle_label.add_theme_constant_override("shadow_offset_x", 2)
		subtitle_label.add_theme_constant_override("shadow_offset_y", 2)
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle_label.text = "剧本总结"
	
	# 设置关闭按钮样式
	if close_button:
		close_button.add_theme_font_size_override("font_size", 40)
		close_button.text = "返回主菜单 (ESC)"
	
	# 设置提示标签样式
	if hint_label:
		hint_label.add_theme_font_size_override("font_size", 32)
		hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.text = "按ESC键返回主菜单"

func _load_summary_data():
	"""加载总结数据"""
	var file = FileAccess.open("res://data/ending_summary.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			summary_data = json.data
			print("[INFO] 结尾总结数据已加载")
		else:
			print("[ERROR] 结尾总结数据JSON解析失败")
		file.close()
	else:
		print("[WARN] 结尾总结数据文件不存在，使用默认内容")
		summary_data = _get_default_summary()

func _get_default_summary() -> Dictionary:
	"""获取默认总结内容"""
	return {
		"title": "《李白的一生》剧本总结",
		"sections": [
			{
				"title": "第一章：初入蜀中",
				"content": "在蜀中，我们见证了李白青年时期的理想与抱负。他怀揣着\"仗剑去国，辞亲远游\"的志向，渴望离开故乡，到更广阔的天地去实现自己的抱负。"
			},
			{
				"title": "第二章：长安岁月",
				"content": "在长安，我们见证了李白人生最辉煌的时期。他进入翰林院，为贵妃写诗，达到了人生的巅峰。但同时也经历了与权贵的冲突，最终被\"赐金放还\"，离开长安。"
			},
			{
				"title": "第三章：流放与漂泊",
				"content": "在流放之路和当涂，我们见证了李白人生的最后阶段。他因加入永王李璘的幕府而被流放，途中遇到大赦，得以返回。最终在当涂去世，享年62岁。"
			},
			{
				"title": "一生的回顾",
				"content": "李白的一生，是理想与现实交织的一生。他始终怀抱着建功立业的理想，但现实却充满了挫折与失意。然而，正是这些经历，造就了他不朽的诗篇，让他成为了中国文学史上最伟大的诗人之一。"
			}
		]
	}

func _input(event: InputEvent):
	"""处理输入事件"""
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		close_summary()
		get_viewport().set_input_as_handled()

func show_summary():
	"""显示总结"""
	visible = true
	_update_summary_content()
	
	# 播放淡入动画
	_play_fade_in_animation()
	
	print("[INFO] 显示结尾总结")

func close_summary():
	"""关闭总结"""
	# 播放淡出动画
	_play_fade_out_animation()
	
	# 延迟后隐藏
	await get_tree().create_timer(0.3).timeout
	visible = false
	
	# 返回主菜单
	_return_to_main_menu()

func _update_summary_content():
	"""更新总结内容"""
	if not content_container:
		return
	
	# 清空现有内容
	for child in content_container.get_children():
		child.queue_free()
	
	# 创建各个部分
	var sections = summary_data.get("sections", [])
	for section in sections:
		_create_section(section.get("title", ""), section.get("content", ""))

func _create_section(title: String, content: String):
	"""创建总结部分"""
	if content.is_empty():
		return
	
	# 创建部分容器
	var section_container = VBoxContainer.new()
	section_container.add_theme_constant_override("separation", 15)
	
	# 创建标题
	var section_title = Label.new()
	section_title.text = "【" + title + "】"
	section_title.add_theme_font_size_override("font_size", 50)  # 大字体
	section_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))  # 金色
	section_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	section_title.add_theme_constant_override("shadow_offset_x", 3)
	section_title.add_theme_constant_override("shadow_offset_y", 3)
	section_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section_container.add_child(section_title)
	
	# 创建内容
	var section_content = RichTextLabel.new()
	section_content.bbcode_enabled = true
	section_content.text = content
	section_content.add_theme_font_size_override("normal_font_size", 42)  # 大字体
	section_content.add_theme_color_override("default_color", Color(0.95, 0.95, 0.9, 1.0))  # 浅色文字
	section_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section_content.fit_content = true
	section_container.add_child(section_content)
	
	# 添加间距
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	section_container.add_child(spacer)
	
	content_container.add_child(section_container)

func _play_fade_in_animation():
	"""播放淡入动画"""
	if not panel:
		return
	
	# 初始状态：透明
	panel.modulate = Color(1, 1, 1, 0)
	
	# 创建补间动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.5)
	tween.tween_property(panel, "scale", Vector2(1, 1), 0.5).from(Vector2(0.95, 0.95))

func _play_fade_out_animation():
	"""播放淡出动画"""
	if not panel:
		return
	
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 0), 0.3)

func _return_to_main_menu():
	"""返回主菜单"""
	print("[INFO] 返回主菜单")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_close_button_pressed():
	"""关闭按钮点击"""
	close_summary()

