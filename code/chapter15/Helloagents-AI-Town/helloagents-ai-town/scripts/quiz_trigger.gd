# 答题触发区域脚本
# 可以在Godot编辑器中直接放置和配置
extends Area2D

# ==================== 导出变量（可在编辑器中配置）====================

@export var quiz_id: String = "region1_bridge"  # 答题ID
@export var target_region: int = 2  # 答对后解锁的区域（2=区域2, 3=区域3）
@export var hint_text: String = "按E键开始答题"  # 提示文字
@export var show_hint: bool = true  # 是否显示提示

# 信号
signal quiz_triggered(quiz_id: String)

# 节点引用
var hint_label: Label = null
var player_in_range: bool = false

func _ready():
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 创建提示标签（如果启用）
	if show_hint:
		create_hint_label()
	
	# 添加到quiz_triggers组
	add_to_group("quiz_triggers")
	
	print("[INFO] 答题触发区域已初始化: ", quiz_id, " 位置: ", global_position)

func create_hint_label():
	"""创建提示标签"""
	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = hint_text
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 设置样式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)  # 半透明黑色背景
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	hint_label.add_theme_stylebox_override("normal", style_box)
	
	# 设置字体颜色
	hint_label.add_theme_color_override("font_color", Color.YELLOW)
	hint_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint_label.add_theme_constant_override("shadow_offset_x", 2)
	hint_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# 设置位置（在触发区域上方）
	hint_label.position = Vector2(-100, -40)  # 相对于Area2D的位置
	hint_label.size = Vector2(200, 30)
	hint_label.visible = false
	
	add_child(hint_label)

func _on_body_entered(body: Node2D):
	"""玩家进入触发区域"""
	if body.is_in_group("player"):
		player_in_range = true
		print("[INFO] 玩家进入答题触发区域: ", quiz_id)
		
		# 显示提示
		if hint_label:
			hint_label.visible = true
		
		# 检查是否已经答过题
		if QuizManager and QuizManager.is_quiz_completed(quiz_id):
			if hint_label:
				hint_label.text = "已完成答题"
				hint_label.add_theme_color_override("font_color", Color.GREEN)

func _on_body_exited(body: Node2D):
	"""玩家离开触发区域"""
	if body.is_in_group("player"):
		player_in_range = false
		print("[INFO] 玩家离开答题触发区域: ", quiz_id)
		
		# 隐藏提示
		if hint_label:
			hint_label.visible = false

func _input(event: InputEvent):
	"""处理输入事件"""
	# 在触发区域内按E键触发答题
	# 注意：需要检查玩家是否正在交互（避免与NPC对话冲突）
	if player_in_range and event.is_action_pressed("ui_accept"):
		# 检查玩家是否正在与其他系统交互
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("get") and "is_interacting" in player:
			if player.is_interacting:
				return  # 如果正在交互，不触发答题
		
		# 检查是否已经答过题
		if QuizManager and QuizManager.is_quiz_completed(quiz_id):
			show_message("你已经完成过这道题了！")
			return
		
		# 触发答题
		trigger_quiz()

func trigger_quiz():
	"""触发答题"""
	print("[INFO] 触发答题: ", quiz_id)
	
	# 发送信号
	quiz_triggered.emit(quiz_id)
	
	# 通知答题UI系统 - 使用多种方式查找
	var quiz_ui = null
	
	# 方法1：通过组查找
	quiz_ui = get_tree().get_first_node_in_group("quiz_ui")
	
	# 方法2：如果组查找失败，直接通过场景树查找
	if not quiz_ui:
		var main = get_tree().get_first_node_in_group("main")
		if main:
			quiz_ui = main.get_node_or_null("QuizUI")
	
	# 方法3：如果还是找不到，从根节点查找
	if not quiz_ui:
		var root = get_tree().root
		quiz_ui = root.get_node_or_null("Main/QuizUI")
	
	# 方法4：遍历场景树查找
	if not quiz_ui:
		quiz_ui = find_quiz_ui_in_tree(get_tree().root)
	
	if quiz_ui:
		print("[INFO] 找到答题UI，开始答题")
		quiz_ui.start_quiz(quiz_id)
	else:
		print("[ERROR] 未找到答题UI，请确保quiz_ui在场景中并添加到quiz_ui组")
		print("[DEBUG] 尝试查找场景树中的所有节点...")
		print_all_nodes(get_tree().root, 0)

func find_quiz_ui_in_tree(node: Node) -> Node:
	"""递归查找QuizUI节点"""
	if node.name == "QuizUI" or (node.has_method("start_quiz")):
		return node
	
	for child in node.get_children():
		var result = find_quiz_ui_in_tree(child)
		if result:
			return result
	
	return null

func print_all_nodes(node: Node, depth: int):
	"""打印所有节点（用于调试）"""
	var indent = ""
	for i in range(depth):
		indent += "  "
	print(indent + "- " + node.name + " (类型: " + node.get_class() + ")")
	if depth < 3:  # 只打印前3层
		for child in node.get_children():
			print_all_nodes(child, depth + 1)

func show_message(message: String):
	"""显示消息（临时实现，可以后续优化）"""
	print("[INFO] ", message)
	# 可以在这里添加更美观的消息显示
