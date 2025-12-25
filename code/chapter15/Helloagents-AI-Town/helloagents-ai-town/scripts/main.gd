# 主场景脚本
extends Node2D

# NPC节点引用
@onready var npc_zhang: Node2D = $NPCs/NPC_Zhang
@onready var npc_li: Node2D = $NPCs/NPC_Li
@onready var npc_wang: Node2D = $NPCs/NPC_Wang

# API客户端
var api_client: Node = null

# NPC状态更新计时器
var status_update_timer: float = 0.0

# 暂停菜单
var pause_menu: Node = null

# ⭐ 语音互动提示UI
var voice_interaction_hint: CanvasLayer = null
var voice_interaction_label: Label = null

func _ready():
	# 添加到main组，方便其他节点查找
	add_to_group("main")
	
	print("[INFO] 主场景初始化")
	
	# 获取API客户端
	api_client = get_node_or_null("/root/APIClient")
	if api_client:
		api_client.npc_status_received.connect(_on_npc_status_received)
		
		# ⭐ 连接外部对话WebSocket状态信号
		api_client.external_dialogue_ws_status_received.connect(_on_external_dialogue_ws_status_received)
		
		# 立即获取一次NPC状态
		api_client.get_npc_status()
	else:
		print("[ERROR] API客户端未找到")
	
	# ⭐ 创建外部程序管理器
	var external_app_manager = preload("res://scripts/external_app_manager.gd").new()
	external_app_manager.name = "ExternalAppManager"
	external_app_manager.add_to_group("external_app_manager")
	get_tree().root.add_child(external_app_manager)
	print("[INFO] 外部程序管理器已添加到场景树")
	
	# ⭐ 连接区域解锁信号
	if RegionManager:
		RegionManager.region_unlocked.connect(_on_region_unlocked)
		print("[INFO] 区域解锁信号已连接")
	
	# ⭐ 验证QuizUI是否存在
	var quiz_ui = get_node_or_null("QuizUI")
	if quiz_ui:
		print("[INFO] ✅ QuizUI节点已找到: ", quiz_ui.name)
		if quiz_ui.is_in_group("quiz_ui"):
			print("[INFO] ✅ QuizUI已添加到quiz_ui组")
		else:
			print("[WARN] ⚠️ QuizUI未添加到quiz_ui组")
	else:
		print("[ERROR] ❌ 未找到QuizUI节点")
	
	# ⭐ 创建暂停菜单
	_create_pause_menu()
	
	# ⭐ 创建语音互动提示UI
	_create_voice_interaction_hint()

func _on_region_unlocked(region_id: int):
	"""区域解锁时的回调"""
	print("[INFO] 🎉 区域 %d 已解锁！" % region_id)
	# 可以在这里播放解锁动画或音效

func _process(delta: float):
	# 定时更新NPC状态
	status_update_timer += delta
	if status_update_timer >= Config.NPC_STATUS_UPDATE_INTERVAL:
		status_update_timer = 0.0
		if api_client:
			api_client.get_npc_status()

func _on_npc_status_received(dialogues: Dictionary):
	"""收到NPC状态更新"""
	print("[INFO] 更新NPC状态: ", dialogues)
	
	# 更新各个NPC的对话
	for npc_name in dialogues:
		var dialogue = dialogues[npc_name]
		update_npc_dialogue(npc_name, dialogue)

func update_npc_dialogue(npc_name: String, dialogue: String):
	"""更新指定NPC的对话"""
	var npc_node = get_npc_node(npc_name)
	if npc_node and npc_node.has_method("update_dialogue"):
		npc_node.update_dialogue(dialogue)

func get_npc_node(npc_name: String) -> Node2D:
	"""根据名字获取NPC节点"""
	match npc_name:
		"老年李白":
			return npc_zhang
		"青年李白":
			return npc_li
		"中年李白":
			return npc_wang
		_:
			return null

# ⭐ 处理外部对话WebSocket状态变化
func _on_external_dialogue_ws_status_received(status: String, message: String):
	"""外部对话WebSocket状态变化回调"""
	print("[INFO] 📡 外部对话WebSocket状态: ", status, " - ", message)
	
	if status == "connected":
		# 显示"语音互动中"提示
		_show_voice_interaction_hint()
	elif status == "disconnected":
		# 隐藏提示
		_hide_voice_interaction_hint()

# ⭐ 创建语音互动提示UI
func _create_voice_interaction_hint():
	"""创建语音互动提示UI"""
	# 创建CanvasLayer
	voice_interaction_hint = CanvasLayer.new()
	voice_interaction_hint.name = "VoiceInteractionHint"
	
	# 创建Control容器
	var control = Control.new()
	control.name = "Control"
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不拦截鼠标事件
	voice_interaction_hint.add_child(control)
	
	# 创建Label
	voice_interaction_label = Label.new()
	voice_interaction_label.name = "HintLabel"
	voice_interaction_label.text = "🎤 语音互动中"
	voice_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	voice_interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 设置位置（屏幕顶部居中）
	voice_interaction_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	voice_interaction_label.offset_top = 20
	voice_interaction_label.offset_left = 0
	voice_interaction_label.offset_right = 0
	voice_interaction_label.offset_bottom = 60
	
	# 设置样式
	voice_interaction_label.add_theme_font_size_override("font_size", 36)
	voice_interaction_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3, 1.0))  # 绿色文字
	
	# 设置背景样式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.0, 0.0, 0.0, 0.6)  # 半透明黑色背景
	style_box.border_color = Color(0.2, 0.9, 0.3, 0.8)  # 绿色边框
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	style_box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style_box.shadow_size = 8
	style_box.shadow_offset = Vector2(0, 4)
	voice_interaction_label.add_theme_stylebox_override("normal", style_box)
	
	control.add_child(voice_interaction_label)
	
	# 添加到场景树
	get_tree().root.add_child(voice_interaction_hint)
	
	# 初始状态：隐藏
	voice_interaction_hint.visible = false
	
	print("[INFO] ✅ 语音互动提示UI已创建")

# ⭐ 显示语音互动提示
func _show_voice_interaction_hint():
	"""显示语音互动提示"""
	if not voice_interaction_hint:
		_create_voice_interaction_hint()
	
	if voice_interaction_hint:
		voice_interaction_hint.visible = true
		
		# 淡入动画
		if voice_interaction_label:
			voice_interaction_label.modulate.a = 0.0
			var tween = create_tween()
			tween.tween_property(voice_interaction_label, "modulate:a", 1.0, 0.3)
		
		print("[INFO] ✅ 显示语音互动提示")

# ⭐ 隐藏语音互动提示
func _hide_voice_interaction_hint():
	"""隐藏语音互动提示"""
	if voice_interaction_hint and voice_interaction_label:
		# 淡出动画
		var tween = create_tween()
		tween.tween_property(voice_interaction_label, "modulate:a", 0.0, 0.3)
		await tween.finished
		voice_interaction_hint.visible = false
		
		print("[INFO] ✅ 隐藏语音互动提示")

func _create_pause_menu():
	"""创建暂停菜单UI"""
	# 加载暂停菜单脚本
	var pause_menu_script = load("res://scripts/pause_menu.gd")
	if not pause_menu_script:
		print("[ERROR] 无法加载暂停菜单脚本")
		return
	
	# 创建CanvasLayer节点
	pause_menu = pause_menu_script.new()
	pause_menu.name = "PauseMenu"
	
	# 创建UI节点结构（增大尺寸）
	var panel = Panel.new()
	panel.name = "Panel"
	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -650
	panel.offset_top = -550
	panel.offset_right = 650
	panel.offset_bottom = 550
	pause_menu.add_child(panel)
	
	# 创建VBoxContainer（直接在面板中心）
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -400  # 宽度的一半（负值）
	vbox.offset_top = -300   # 高度的一半（负值，根据内容调整）
	vbox.offset_right = 400  # 宽度的一半
	vbox.offset_bottom = 300 # 高度的一半（根据内容调整）
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER  # 内容居中对齐
	vbox.add_theme_constant_override("separation", 30)  # 设置按钮之间的间距
	panel.add_child(vbox)
	
	# 创建标题（增大尺寸）
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "游戏菜单"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(title_label)
	
	# 添加分隔符
	var separator1 = HSeparator.new()
	separator1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(separator1)
	
	# 创建继续按钮（增大尺寸，设置宽度）
	var continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "继续游戏"
	continue_button.custom_minimum_size = Vector2(600, 100)  # 设置固定宽度
	vbox.add_child(continue_button)
	
	# 创建返回主菜单按钮（增大尺寸，设置宽度）
	var main_menu_button = Button.new()
	main_menu_button.name = "MainMenuButton"
	main_menu_button.text = "返回主菜单"
	main_menu_button.custom_minimum_size = Vector2(600, 100)  # 设置固定宽度
	vbox.add_child(main_menu_button)
	
	# 创建退出游戏按钮（增大尺寸，设置宽度）
	var exit_button = Button.new()
	exit_button.name = "ExitButton"
	exit_button.text = "退出游戏"
	exit_button.custom_minimum_size = Vector2(600, 100)  # 设置固定宽度
	vbox.add_child(exit_button)
	
	# 将暂停菜单添加到当前场景（main节点）
	add_child(pause_menu)
	
	# 验证暂停菜单是否已正确添加
	if pause_menu and pause_menu.is_inside_tree():
		print("[INFO] ✅ 暂停菜单已创建并添加到场景树")
		print("[DEBUG] 暂停菜单节点路径: ", pause_menu.get_path())
		print("[DEBUG] 暂停菜单父节点: ", pause_menu.get_parent().name)
	else:
		print("[ERROR] ❌ 暂停菜单添加失败")
