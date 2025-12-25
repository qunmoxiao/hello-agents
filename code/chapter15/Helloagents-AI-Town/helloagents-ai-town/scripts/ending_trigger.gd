# 结尾总结触发区域脚本
# 在草庐位置触发剧本总结
extends Area2D

# ==================== 导出变量（可在编辑器中配置）====================

@export var hint_text: String = "按E键查看剧本总结"  # 提示文字
@export var show_hint: bool = true  # 是否显示提示
@export var required_quest: String = "quest_006"  # 前置任务（完成答题任务后才能触发）

# 信号
signal ending_triggered()

# 节点引用
var hint_label: Label = null
var player_in_range: bool = false
var has_triggered: bool = false  # 是否已触发过（只能触发一次）

func _ready():
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 创建提示标签（如果启用）
	if show_hint:
		create_hint_label()
	
	# 添加到ending_triggers组
	add_to_group("ending_triggers")
	
	print("[INFO] 结尾总结触发区域已初始化，位置: ", global_position)

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
	
	# 设置字体颜色（金色，突出重要性）
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	hint_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint_label.add_theme_font_size_override("font_size", 24)
	hint_label.add_theme_constant_override("shadow_offset_x", 2)
	hint_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# 设置位置（在触发区域上方）
	hint_label.position = Vector2(-120, -50)  # 相对于Area2D的位置
	hint_label.size = Vector2(240, 35)
	hint_label.visible = false
	
	add_child(hint_label)

func _on_body_entered(body: Node2D):
	"""玩家进入触发区域"""
	if body.is_in_group("player"):
		player_in_range = true
		print("[INFO] 玩家进入结尾总结触发区域")
		
		# 如果已触发过，不显示提示
		if has_triggered:
			if hint_label:
				hint_label.text = "已查看总结"
				hint_label.add_theme_color_override("font_color", Color.GREEN)
				hint_label.visible = true
			return
		
		# 检查前置任务
		if required_quest != "":
			if not _check_required_quest():
				if hint_label:
					hint_label.text = "请先完成最终答题"
					hint_label.add_theme_color_override("font_color", Color.YELLOW)
					hint_label.visible = true
				return
		
		# 显示提示
		if hint_label:
			hint_label.visible = true

func _on_body_exited(body: Node2D):
	"""玩家离开触发区域"""
	if body.is_in_group("player"):
		player_in_range = false
		print("[INFO] 玩家离开结尾总结触发区域")
		
		# 隐藏提示
		if hint_label:
			hint_label.visible = false

func _input(event: InputEvent):
	"""处理输入事件"""
	# 在触发区域内按E键触发结尾总结
	if player_in_range and event.is_action_pressed("ui_accept"):
		# 检查玩家是否正在与其他系统交互
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("get") and "is_interacting" in player:
			if player.is_interacting:
				return  # 如果正在交互，不触发
		
		# 如果已触发过，不再触发
		if has_triggered:
			show_message("你已经查看过剧本总结了！")
			return
		
		# 检查前置任务
		if required_quest != "":
			if not _check_required_quest():
				show_message("请先完成最终答题任务！")
				return
		
		# 触发结尾总结
		trigger_ending()

func trigger_ending():
	"""触发结尾总结"""
	print("[INFO] 触发结尾总结")
	
	# 标记为已触发
	has_triggered = true
	
	# ⭐ 完成任务 quest_009（思考一生）
	if has_node("/root/QuestManager"):
		# 检查任务是否存在且未完成
		if QuestManager.is_quest_active("quest_009"):
			print("[INFO] ✅ 完成任务：思考一生")
			QuestManager.complete_quest("quest_009")
		elif not QuestManager.is_quest_completed("quest_009"):
			# 如果任务未激活，先启动任务再完成
			print("[INFO] 启动并完成任务：思考一生")
			QuestManager.start_quest("quest_009")
			QuestManager.complete_quest("quest_009")
	
	# 发送信号
	ending_triggered.emit()
	
	# 通知结尾总结UI系统
	var ending_ui = null
	
	# 方法1：通过组查找
	ending_ui = get_tree().get_first_node_in_group("ending_summary_ui")
	
	# 方法2：如果组查找失败，直接通过场景树查找
	if not ending_ui:
		var main = get_tree().get_first_node_in_group("main")
		if main:
			ending_ui = main.get_node_or_null("EndingSummaryUI")
	
	# 方法3：如果还是找不到，从根节点查找
	if not ending_ui:
		var root = get_tree().root
		ending_ui = root.get_node_or_null("Main/EndingSummaryUI")
	
	if ending_ui:
		print("[INFO] 找到结尾总结UI，显示总结")
		ending_ui.show_summary()
	else:
		print("[ERROR] 未找到结尾总结UI，请确保EndingSummaryUI在场景中并添加到ending_summary_ui组")

func _check_required_quest() -> bool:
	"""检查前置任务是否完成"""
	if required_quest == "":
		return true
	
	if not has_node("/root/QuestManager"):
		print("[WARN] QuestManager未找到，无法检查前置任务")
		return false
	
	return QuestManager.is_quest_completed(required_quest)

func show_message(message: String):
	"""显示消息（临时实现，可以后续优化）"""
	print("[INFO] ", message)
	# 可以在这里添加更美观的消息显示

