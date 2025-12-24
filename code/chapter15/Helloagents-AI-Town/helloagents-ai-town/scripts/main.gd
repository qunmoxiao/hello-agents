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

func _ready():
	# 添加到main组，方便其他节点查找
	add_to_group("main")
	
	print("[INFO] 主场景初始化")
	
	# 获取API客户端
	api_client = get_node_or_null("/root/APIClient")
	if api_client:
		api_client.npc_status_received.connect(_on_npc_status_received)
		
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
