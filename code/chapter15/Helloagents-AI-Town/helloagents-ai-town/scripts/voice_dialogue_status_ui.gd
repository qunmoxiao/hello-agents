# 语音对话状态UI脚本
extends CanvasLayer

@onready var control: Control = $Control
@onready var panel: Panel = $Control/Panel
@onready var hbox_container: HBoxContainer = $Control/Panel/HBoxContainer
@onready var icon_label: Label = $Control/Panel/HBoxContainer/IconLabel
@onready var text_label: Label = $Control/Panel/HBoxContainer/TextLabel

var current_tween: Tween = null
var is_showing: bool = false
var display_duration: float = 4.0  # 显示持续时间（秒）
var is_testing: bool = false  # 测试模式标志

func _ready():
	visible = false
	# 设置鼠标过滤，不影响游戏操作
	if control:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 连接信号
	if has_node("/root/APIClient"):
		APIClient.external_dialogue_ws_status_received.connect(_on_ws_status_received)
		print("[INFO] ✅ 语音对话状态UI已连接到APIClient信号")
	else:
		print("[WARN] ⚠️ APIClient未找到，语音对话状态UI无法接收状态更新")
		# ⭐ 如果没有APIClient，自动运行一次测试
		print("[INFO] 🧪 自动运行UI测试（模拟2轮操作）")
		call_deferred("_run_test")
	
	# 设置初始样式
	_setup_ui_style()

func _input(event: InputEvent):
	"""处理输入事件 - 按V键触发测试"""
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		# 按V键触发测试
		if not is_testing:
			print("[INFO] 🧪 手动触发UI测试（模拟2轮操作）")
			_run_test()
		get_viewport().set_input_as_handled()

func _on_ws_status_received(status: String, message: String):
	"""处理WebSocket状态变化"""
	print("[INFO] 📡 收到WebSocket状态更新: ", status, " - ", message)
	
	if status == "connected":
		show_connected_status()
	elif status == "disconnected":
		show_disconnected_status()

func show_connected_status():
	"""显示连接状态"""
	if is_showing:
		# 如果正在显示，先停止当前动画
		_stop_current_animation()
	
	is_showing = true
	icon_label.text = "🎤"
	text_label.text = "语音对话已连接"
	_setup_ui_style_for_status(true)  # true = 连接状态（绿色）
	_show_with_animation()  # 注意：这是异步函数，但这里不await，让调用者决定是否等待

func show_disconnected_status():
	"""显示断开状态"""
	if is_showing:
		# 如果正在显示，先停止当前动画
		_stop_current_animation()
	
	is_showing = true
	icon_label.text = "🔇"
	text_label.text = "语音对话已结束"
	_setup_ui_style_for_status(false)  # false = 断开状态（橙色）
	_show_with_animation()  # 注意：这是异步函数，但这里不await，让调用者决定是否等待

func _setup_ui_style():
	"""设置UI基础样式"""
	# 设置全屏背景（透明，不阻挡游戏）
	if control:
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 设置面板样式（大尺寸，适合青少年）
	if panel:
		# 使用PRESET_CENTER然后调整到顶部
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.custom_minimum_size = Vector2(1000, 200)  # 减小宽度到1000
		# 手动设置锚点和偏移，实现顶部居中
		panel.anchor_left = 0.5
		panel.anchor_top = 0.0
		panel.anchor_right = 0.5
		panel.anchor_bottom = 0.0
		panel.offset_top = 50  # 距离顶部50像素
		panel.offset_left = -500  # 居中：宽度的一半
		panel.offset_right = 500
		panel.offset_bottom = 250
	
	# 设置HBoxContainer布局
	if hbox_container:
		hbox_container.add_theme_constant_override("separation", 30)  # 图标和文字间距
		hbox_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# 设置图标样式（大号字体）
	if icon_label:
		icon_label.add_theme_font_size_override("font_size", 120)  # 超大图标
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.custom_minimum_size = Vector2(150, 150)  # 确保图标有足够空间
	
	# 设置文本样式（大号字体）
	if text_label:
		text_label.add_theme_font_size_override("font_size", 80)  # 大号字体
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _setup_ui_style_for_status(is_connected: bool):
	"""根据连接状态设置UI颜色样式"""
	if not panel:
		return
	
	var style_box = StyleBoxFlat.new()
	
	if is_connected:
		# 连接状态：绿色主题
		style_box.bg_color = Color(0.2, 0.8, 0.3, 0.95)  # 绿色背景
		style_box.border_color = Color(0.1, 0.6, 0.2, 1.0)  # 深绿色边框
		icon_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))  # 白色图标
		text_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))  # 白色文字
	else:
		# 断开状态：橙色主题
		style_box.bg_color = Color(0.95, 0.6, 0.2, 0.95)  # 橙色背景
		style_box.border_color = Color(0.8, 0.4, 0.1, 1.0)  # 深橙色边框
		icon_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))  # 白色图标
		text_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))  # 白色文字
	
	# 设置边框和圆角
	style_box.border_width_left = 8
	style_box.border_width_top = 8
	style_box.border_width_right = 8
	style_box.border_width_bottom = 8
	style_box.corner_radius_top_left = 20
	style_box.corner_radius_top_right = 20
	style_box.corner_radius_bottom_left = 20
	style_box.corner_radius_bottom_right = 20
	
	# 添加阴影效果
	style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style_box.shadow_size = 15
	style_box.shadow_offset = Vector2(0, 8)
	
	panel.add_theme_stylebox_override("panel", style_box)

func _show_with_animation():
	"""显示动画（淡入 -> 保持 -> 淡出）"""
	visible = true
	
	# 初始状态：透明且在上方（从顶部滑入）
	panel.modulate.a = 0.0
	panel.position.y = -250  # 初始位置在屏幕上方
	
	# 清除之前的动画
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	# 淡入动画（0.4秒）
	current_tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	
	# 滑入动画（0.4秒，从上方滑入）
	current_tween.tween_property(panel, "position:y", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# 等待显示持续时间
	await get_tree().create_timer(display_duration).timeout
	
	# 淡出动画（0.5秒）
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	current_tween.tween_property(panel, "position:y", -250.0, 0.5).set_ease(Tween.EASE_IN)
	
	await get_tree().create_timer(0.5).timeout
	
	# 隐藏并重置状态
	visible = false
	panel.position.y = 0.0  # 重置位置
	is_showing = false

func _stop_current_animation():
	"""停止当前动画"""
	if current_tween:
		current_tween.kill()
		current_tween = null
	is_showing = false

func _run_test():
	"""运行测试：模拟2轮WebSocket连接/断开操作"""
	if is_testing:
		print("[WARN] 测试已在进行中，跳过")
		return
	
	is_testing = true
	print("[INFO] 🧪 开始UI测试：模拟2轮操作")
	
	# 等待一帧，确保节点已准备好
	await get_tree().process_frame
	
	# 第一轮：连接 -> 断开
	print("[INFO] 🧪 第一轮：模拟连接...")
	show_connected_status()
	# 等待动画完成：淡入(0.4) + 显示(4.0) + 淡出(0.5) + 间隔(1.0) = 5.9秒
	await get_tree().create_timer(display_duration + 0.9 + 1.0).timeout
	
	print("[INFO] 🧪 第一轮：模拟断开...")
	show_disconnected_status()
	await get_tree().create_timer(display_duration + 0.9 + 1.0).timeout
	
	# 第二轮：连接 -> 断开
	print("[INFO] 🧪 第二轮：模拟连接...")
	show_connected_status()
	await get_tree().create_timer(display_duration + 0.9 + 1.0).timeout
	
	print("[INFO] 🧪 第二轮：模拟断开...")
	show_disconnected_status()
	await get_tree().create_timer(display_duration + 0.9 + 1.0).timeout
	
	print("[INFO] 🧪 UI测试完成！")
	is_testing = false
