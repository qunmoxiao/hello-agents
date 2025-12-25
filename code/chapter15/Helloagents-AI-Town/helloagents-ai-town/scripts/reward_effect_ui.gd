# 奖励效果UI脚本
extends CanvasLayer

signal reward_finished

@onready var control: Control = $Control
@onready var panel: Panel = $Control/Panel
@onready var icon_label: Label = $Control/Panel/VBoxContainer/IconLabel
@onready var text_label: Label = $Control/Panel/VBoxContainer/TextLabel

var current_tween: Tween = null
var is_playing: bool = false  # ⭐ 标志：是否正在播放动画

func _ready():
	visible = false
	# 设置鼠标过滤，不影响游戏操作
	if control:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_keyword_reward(keyword, chapter: int):
	"""显示关键词收集奖励
	Args:
		keyword: 收集到的关键词（可能是字符串或数组）
		chapter: 当前章节（1, 2, 3）
	"""
	# ⭐ 如果正在播放动画，等待前一个动画完成
	if is_playing:
		print("[DEBUG] 等待前一个奖励动画完成...")
		await reward_finished
		# 等待一帧，确保状态已重置
		await get_tree().process_frame
	
	# ⭐ 设置播放标志
	is_playing = true
	
	_setup_ui_style(chapter)
	
	# ⭐ 确保只显示主关键词（处理各种可能的输入格式）
	var display_keyword: String = ""
	
	# 调试：打印接收到的 keyword 类型和内容
	print("[DEBUG] RewardEffectUI 接收到的 keyword 类型: ", typeof(keyword), " 内容: ", keyword)
	
	if keyword is Array:
		# 如果是数组，只取第一个元素（主关键词）
		if keyword.size() > 0:
			display_keyword = str(keyword[0])
			print("[DEBUG] 从数组中提取主关键词: ", display_keyword)
		else:
			display_keyword = ""
	else:
		# 如果是字符串，检查是否包含数组格式（可能是字符串化的数组）
		var keyword_str = str(keyword)
		# 检查是否是 JSON 数组格式的字符串（如 '["关键词1", "关键词2"]'）
		if keyword_str.begins_with("[") and keyword_str.ends_with("]"):
			# 尝试解析 JSON 数组
			var json = JSON.new()
			var parse_result = json.parse(keyword_str)
			if parse_result == OK:
				var parsed_array = json.data
				if parsed_array is Array and parsed_array.size() > 0:
					display_keyword = str(parsed_array[0])
					print("[DEBUG] 从 JSON 字符串中解析并提取主关键词: ", display_keyword)
				else:
					display_keyword = keyword_str
			else:
				# 解析失败，直接使用字符串
				display_keyword = keyword_str
		else:
			# 普通字符串，直接使用
			display_keyword = keyword_str
	
	# 设置图标和文本
	icon_label.text = "✓"
	text_label.text = "收集到关键词：\n%s" % display_keyword
	print("[DEBUG] 最终显示的关键词: ", display_keyword)
	
	# 显示并播放动画（等待动画完成）
	await _play_reward_animation()
	
	# ⭐ 重置播放标志
	is_playing = false

func show_quiz_reward(correct_count: int, chapter: int):
	"""显示答题正确奖励
	Args:
		correct_count: 已答对的题目数量
		chapter: 当前章节（1, 2, 3）
	"""
	# ⭐ 如果正在播放动画，等待前一个动画完成
	if is_playing:
		print("[DEBUG] 等待前一个奖励动画完成...")
		await reward_finished
		# 等待一帧，确保状态已重置
		await get_tree().process_frame
	
	# ⭐ 设置播放标志
	is_playing = true
	
	_setup_ui_style(chapter)
	
	# 设置图标和文本（根据答对题目数量显示）
	icon_label.text = "⭐"
	if correct_count == 1:
		text_label.text = "答对 1 题！"
	else:
		text_label.text = "答对 %d 题！" % correct_count
	
	# 显示并播放动画（等待动画完成）
	await _play_reward_animation()
	
	# ⭐ 重置播放标志
	is_playing = false

func _setup_ui_style(chapter: int):
	"""根据章节设置UI样式（大号特效）
	Args:
		chapter: 当前章节（1, 2, 3）
	"""
	# 设置全屏背景（透明，不阻挡游戏）
	if control:
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 设置面板样式（超大尺寸）
	if panel:
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.custom_minimum_size = Vector2(1600, 600)  # 超大尺寸面板（从1200x400增大到1600x500）
		panel.offset_left = -800
		panel.offset_top = -300
		panel.offset_right = 800
		panel.offset_bottom = 300
		
		# 根据章节设置颜色
		var style_box = StyleBoxFlat.new()
		match chapter:
			1:  # 章节1：青年时期 - 绿色系
				style_box.bg_color = Color(0.2, 0.7, 0.3, 0.95)  # 绿色背景
				style_box.border_color = Color(0.1, 0.5, 0.2, 1.0)  # 深绿色边框
			2:  # 章节2：中年时期 - 金色系
				style_box.bg_color = Color(0.9, 0.7, 0.2, 0.95)  # 金色背景
				style_box.border_color = Color(0.7, 0.5, 0.1, 1.0)  # 深金色边框
			3:  # 章节3：老年时期 - 棕色系
				style_box.bg_color = Color(0.6, 0.5, 0.4, 0.95)  # 棕色背景
				style_box.border_color = Color(0.4, 0.3, 0.2, 1.0)  # 深棕色边框
			_:  # 默认：绿色
				style_box.bg_color = Color(0.2, 0.7, 0.3, 0.95)
				style_box.border_color = Color(0.1, 0.5, 0.2, 1.0)
		
		style_box.border_width_left = 8
		style_box.border_width_top = 8
		style_box.border_width_right = 8
		style_box.border_width_bottom = 8
		style_box.corner_radius_top_left = 20
		style_box.corner_radius_top_right = 20
		style_box.corner_radius_bottom_left = 20
		style_box.corner_radius_bottom_right = 20
		style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		style_box.shadow_size = 15
		style_box.shadow_offset = Vector2(0, 8)
		panel.add_theme_stylebox_override("panel", style_box)
	
	# 设置图标样式（超大号）
	if icon_label:
		icon_label.add_theme_font_size_override("font_size", 150)  # 超大图标（从120增大到150）
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# 根据章节设置图标颜色
		match chapter:
			1:  # 绿色
				icon_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))  # 白色图标
			2:  # 金色
				icon_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))  # 浅金色图标
			3:  # 棕色
				icon_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85, 1.0))  # 浅棕色图标
			_:
				icon_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	
	# 设置文本样式（大号字体）
	if text_label:
		text_label.add_theme_font_size_override("font_size", 90)  # 大号字体（从72增大到90）
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# 根据章节设置文本颜色
		match chapter:
			1:  # 绿色
				text_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))  # 白色文字
			2:  # 金色
				text_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))  # 浅金色文字
			3:  # 棕色
				text_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85, 1.0))  # 浅棕色文字
			_:
				text_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

func _play_reward_animation():
	"""播放奖励动画"""
	visible = true
	
	# 初始状态：透明且缩小
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.5, 0.5)
	
	# 清除之前的动画
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	# 淡入动画（0.3秒）
	current_tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	
	# 放大动画（0.3秒，从0.5到1.1，然后回弹到1.0）
	current_tween.tween_property(panel, "scale", Vector2(1.1, 1.1), 0.3)
	await get_tree().create_timer(0.3).timeout
	
	# 回弹动画（0.2秒，从1.1到1.0）
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.2)
	
	# 停留1.5秒
	await get_tree().create_timer(1.5).timeout
	
	# 淡出动画（0.5秒）
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	await get_tree().create_timer(0.5).timeout
	
	# 隐藏并发送完成信号
	visible = false
	reward_finished.emit()

