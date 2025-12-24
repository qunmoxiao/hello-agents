# 暂停/退出菜单脚本
extends CanvasLayer

# 节点引用
var panel: Panel = null
var continue_button: Button = null
var main_menu_button: Button = null
var exit_button: Button = null
var title_label: Label = null

# 主菜单场景路径
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu.tscn"

# 是否暂停状态
var is_paused: bool = false

# 当前章节
var current_chapter: int = 1

func _ready():
	"""初始化暂停菜单"""
	# 初始隐藏
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # 确保即使游戏暂停也能响应输入
	
	print("[DEBUG] 暂停菜单_ready开始，节点路径: ", get_path())
	
	# 等待一帧，确保子节点已创建
	await get_tree().process_frame
	
	# 获取节点引用
	_initialize_nodes()
	
	# 连接按钮信号
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
		print("[DEBUG] 继续按钮信号已连接")
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)
		print("[DEBUG] 主菜单按钮信号已连接")
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)
		print("[DEBUG] 退出按钮信号已连接")
	
	# 获取当前章节
	_update_current_chapter()
	
	# 设置UI样式
	_setup_ui_style()
	
	print("[INFO] 暂停菜单初始化完成")
	print("[DEBUG] 节点路径: ", get_path())
	print("[DEBUG] 在场景树中: ", is_inside_tree())
	print("[DEBUG] process_mode: ", process_mode)
	print("[DEBUG] visible: ", visible)
	print("[DEBUG] 暂停菜单准备就绪，等待Esc键输入...")

func _initialize_nodes():
	"""初始化节点引用"""
	panel = get_node_or_null("Panel")
	if panel:
		var vbox = panel.get_node_or_null("VBoxContainer")
		if vbox:
			title_label = vbox.get_node_or_null("TitleLabel")
			continue_button = vbox.get_node_or_null("ContinueButton")
			main_menu_button = vbox.get_node_or_null("MainMenuButton")
			exit_button = vbox.get_node_or_null("ExitButton")
			print("[DEBUG] 暂停菜单节点引用已获取")
		else:
			print("[WARN] 未找到VBoxContainer")
	else:
		print("[WARN] 未找到Panel节点")

func _input(event: InputEvent):
	"""处理输入事件"""
	# 调试：打印所有Esc键事件
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		print("[DEBUG] 暂停菜单收到Esc键事件, pressed=", event.pressed, ", echo=", event.echo, ", is_paused=", is_paused, ", visible=", visible, ", 节点路径=", get_path())
	
	# 如果菜单已经打开，Esc键应该关闭菜单
	if is_paused and visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			print("[DEBUG] Esc键 - 关闭暂停菜单")
			resume_game()
			get_viewport().set_input_as_handled()
			return
	
	# 如果对话框或其他UI打开，不处理Esc键
	if _is_other_ui_open():
		print("[DEBUG] 其他UI打开，不处理Esc键")
		return
	
	# 检测Esc键（仅在游戏未暂停时）
	if not is_paused:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			print("[DEBUG] Esc键 - 打开暂停菜单")
			pause_game()
			get_viewport().set_input_as_handled()

func _is_other_ui_open() -> bool:
	"""检查是否有其他UI打开（不包括常驻UI如任务UI）"""
	# 检查对话UI是否打开
	var dialogue_ui = get_tree().get_first_node_in_group("dialogue_system")
	if dialogue_ui and dialogue_ui.visible:
		print("[DEBUG] 对话UI打开，不处理Esc键")
		return true
	
	# 注意：任务UI是常驻UI，不需要检查
	
	# 检查背包UI是否打开
	var inventory_ui = get_node_or_null("/root/Main/InventoryUI")
	if not inventory_ui:
		inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui and inventory_ui.visible:
		print("[DEBUG] 背包UI打开，不处理Esc键")
		return true
	
	# 检查线索UI是否打开
	var clue_ui = get_node_or_null("/root/Main/ClueUI")
	if not clue_ui:
		clue_ui = get_tree().get_first_node_in_group("clue_ui")
	if clue_ui and clue_ui.visible:
		print("[DEBUG] 线索UI打开，不处理Esc键")
		return true
	
	# 检查场景指南UI是否打开
	var scene_guide_ui = get_tree().get_first_node_in_group("scene_guide_ui")
	if scene_guide_ui and scene_guide_ui.visible:
		print("[DEBUG] 场景指南UI打开，不处理Esc键")
		return true
	
	# 检查答题UI是否打开
	var quiz_ui = get_tree().get_first_node_in_group("quiz_ui")
	if quiz_ui and quiz_ui.visible:
		print("[DEBUG] 答题UI打开，不处理Esc键")
		return true
	
	return false

func toggle_pause():
	"""切换暂停状态"""
	if is_paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	"""暂停游戏"""
	if is_paused:
		return
	
	print("[DEBUG] 暂停游戏 - 显示暂停菜单")
	
	# 更新当前章节（每次打开菜单时更新）
	_update_current_chapter()
	
	# 根据章节更新样式
	_setup_ui_style()
	
	is_paused = true
	visible = true
	
	# 暂停游戏（暂停所有节点，除了这个UI）
	get_tree().paused = true
	
	# 聚焦继续按钮
	if continue_button:
		continue_button.grab_focus()
		print("[DEBUG] 继续按钮已聚焦")
	else:
		print("[WARN] 继续按钮未找到，无法聚焦")
	
	print("[INFO] 游戏已暂停")

func resume_game():
	"""恢复游戏"""
	if not is_paused:
		return
	
	is_paused = false
	visible = false
	
	# 恢复游戏
	get_tree().paused = false
	
	print("[INFO] 游戏已恢复")

func _on_continue_button_pressed():
	"""继续游戏按钮点击"""
	print("[INFO] 点击继续游戏")
	resume_game()

func _on_main_menu_button_pressed():
	"""返回主菜单按钮点击"""
	print("[INFO] 点击返回主菜单")
	# 恢复游戏状态（取消暂停）
	get_tree().paused = false
	# 切换到主菜单场景
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_exit_button_pressed():
	"""退出游戏按钮点击"""
	print("[INFO] 点击退出游戏")
	# 退出游戏
	get_tree().quit()

func _update_current_chapter():
	"""更新当前章节"""
	# 区域1 = 章节1，区域2 = 章节2，区域3 = 章节3
	if has_node("/root/RegionManager"):
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var player_x = player.global_position.x
			current_chapter = RegionManager.get_region_from_x(player_x)
		else:
			# 如果找不到玩家，根据解锁的区域判断
			if RegionManager:
				var unlocked_regions = RegionManager.unlocked_regions
				if unlocked_regions != null and unlocked_regions.size() > 0:
					current_chapter = unlocked_regions[-1]  # 返回最大解锁区域
				else:
					current_chapter = 1
			else:
				current_chapter = 1
	else:
		current_chapter = 1
	
	print("[DEBUG] 当前章节: ", current_chapter)

func _setup_ui_style():
	"""设置UI样式（根据章节动态调整）"""
	# 设置面板样式（根据章节）
	if panel:
		var style_box = StyleBoxFlat.new()
		
		# 根据章节设置不同风格
		match current_chapter:
			1:  # 第一章：蜀中 - 古朴、自然、绿色调
				style_box.bg_color = Color(0.12, 0.2, 0.15, 0.3)  # 透明绿色背景
				style_box.border_color = Color(0.5, 0.8, 0.6, 1.0)  # 浅绿色边框
			2:  # 第二章：长安 - 华丽、金色、红色调
				style_box.bg_color = Color(0.25, 0.18, 0.12, 0.3)  # 透明金色背景
				style_box.border_color = Color(1.0, 0.85, 0.4, 1.0)  # 金色边框
			3:  # 第三章：流放 - 沧桑、深色、棕色调
				style_box.bg_color = Color(0.15, 0.12, 0.1, 0.3)  # 透明棕色背景
				style_box.border_color = Color(0.7, 0.6, 0.5, 1.0)  # 浅棕色边框
			_:  # 默认
				style_box.bg_color = Color(0.1, 0.1, 0.15, 0.3)
				style_box.border_color = Color(0.4, 0.75, 0.9, 1.0)
		
		style_box.border_width_left = 6
		style_box.border_width_top = 6
		style_box.border_width_right = 6
		style_box.border_width_bottom = 6
		style_box.corner_radius_top_left = 25
		style_box.corner_radius_top_right = 25
		style_box.corner_radius_bottom_left = 25
		style_box.corner_radius_bottom_right = 25
		style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
		style_box.shadow_size = 25
		style_box.shadow_offset = Vector2(0, 10)
		panel.add_theme_stylebox_override("panel", style_box)
	
	# 设置标题样式（根据章节）
	if title_label:
		title_label.add_theme_font_size_override("font_size", 100)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# 根据章节设置标题颜色和文本
		match current_chapter:
			1:  # 蜀中
				title_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7, 1.0))
				title_label.text = "游戏菜单 🌿"
			2:  # 长安
				title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
				title_label.text = "游戏菜单 ✨"
			3:  # 流放
				title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.6, 1.0))
				title_label.text = "游戏菜单 🍂"
			_:
				title_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.9, 1.0))
				title_label.text = "游戏菜单"
		
		title_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.2, 0.3, 0.9))
		title_label.add_theme_constant_override("shadow_offset_x", 5)
		title_label.add_theme_constant_override("shadow_offset_y", 5)
	
	# 设置按钮样式（根据章节，添加颜文字）
	if continue_button:
		continue_button.add_theme_font_size_override("font_size", 72)
		match current_chapter:
			1:
				continue_button.text = "继续游戏 🌱"
				_setup_button_style(continue_button, Color(0.2, 0.7, 0.3, 1.0), Color(0.3, 0.8, 0.4, 1.0))
			2:
				continue_button.text = "继续游戏 ⭐"
				_setup_button_style(continue_button, Color(0.9, 0.7, 0.2, 1.0), Color(1.0, 0.8, 0.3, 1.0))
			3:
				continue_button.text = "继续游戏 🍁"
				_setup_button_style(continue_button, Color(0.6, 0.4, 0.2, 1.0), Color(0.7, 0.5, 0.3, 1.0))
			_:
				continue_button.text = "继续游戏 ▶"
				_setup_button_style(continue_button, Color(0.2, 0.7, 0.3, 1.0), Color(0.3, 0.8, 0.4, 1.0))
	
	if main_menu_button:
		main_menu_button.add_theme_font_size_override("font_size", 72)
		match current_chapter:
			1:
				main_menu_button.text = "返回主菜单 🏠"
				_setup_button_style(main_menu_button, Color(0.4, 0.6, 0.5, 1.0), Color(0.5, 0.7, 0.6, 1.0))
			2:
				main_menu_button.text = "返回主菜单 🏛️"
				_setup_button_style(main_menu_button, Color(0.7, 0.6, 0.4, 1.0), Color(0.8, 0.7, 0.5, 1.0))
			3:
				main_menu_button.text = "返回主菜单 🚪"
				_setup_button_style(main_menu_button, Color(0.5, 0.4, 0.3, 1.0), Color(0.6, 0.5, 0.4, 1.0))
			_:
				main_menu_button.text = "返回主菜单 🏠"
				_setup_button_style(main_menu_button, Color(0.4, 0.5, 0.7, 1.0), Color(0.5, 0.6, 0.8, 1.0))
	
	if exit_button:
		exit_button.add_theme_font_size_override("font_size", 72)
		match current_chapter:
			1:
				exit_button.text = "退出游戏 👋"
				_setup_button_style(exit_button, Color(0.7, 0.3, 0.2, 1.0), Color(0.8, 0.4, 0.3, 1.0))
			2:
				exit_button.text = "退出游戏 🚪"
				_setup_button_style(exit_button, Color(0.8, 0.4, 0.2, 1.0), Color(0.9, 0.5, 0.3, 1.0))
			3:
				exit_button.text = "退出游戏 🌙"
				_setup_button_style(exit_button, Color(0.6, 0.3, 0.2, 1.0), Color(0.7, 0.4, 0.3, 1.0))
			_:
				exit_button.text = "退出游戏 ❌"
				_setup_button_style(exit_button, Color(0.7, 0.2, 0.2, 1.0), Color(0.8, 0.3, 0.3, 1.0))

func _setup_button_style(button: Button, normal_color: Color, hover_color: Color):
	"""设置按钮样式（根据章节优化）"""
	# 根据章节调整边框颜色
	var border_color = Color(0.9, 0.85, 0.7, 1.0)
	match current_chapter:
		1:  # 蜀中 - 绿色边框
			border_color = Color(0.6, 0.9, 0.7, 1.0)
		2:  # 长安 - 金色边框
			border_color = Color(1.0, 0.9, 0.6, 1.0)
		3:  # 流放 - 棕色边框
			border_color = Color(0.8, 0.7, 0.6, 1.0)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = normal_color
	style_normal.border_color = border_color
	style_normal.border_width_left = 4
	style_normal.border_width_top = 4
	style_normal.border_width_right = 4
	style_normal.border_width_bottom = 4
	style_normal.corner_radius_top_left = 15
	style_normal.corner_radius_top_right = 15
	style_normal.corner_radius_bottom_left = 15
	style_normal.corner_radius_bottom_right = 15
	style_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style_normal.shadow_size = 8
	style_normal.shadow_offset = Vector2(0, 4)
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = hover_color
	style_hover.border_color = border_color.lightened(0.2)
	style_hover.shadow_size = 10
	style_hover.shadow_offset = Vector2(0, 5)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = normal_color.darkened(0.15)
	style_pressed.shadow_size = 4
	style_pressed.shadow_offset = Vector2(0, 2)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	# 设置按钮文字颜色（Button默认文字居中，无需额外设置）
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.95, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.95, 0.95, 0.9, 1.0))
