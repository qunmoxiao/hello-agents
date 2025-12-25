# 线索触发区域脚本
# 可以在Godot编辑器中直接放置和配置
extends Area2D

# ==================== 导出变量（可在编辑器中配置）====================

@export var clue_id: String = "clue_001"  # 线索ID
@export var hint_text: String = "按E键获取线索"  # 提示文字
@export var show_hint: bool = true  # 是否显示提示
@export var one_time_only: bool = true  # 是否只能收集一次（收集后消失）
@export var required_quest: String = ""  # 前置任务（可选，完成该任务后才能收集）

# 信号
signal clue_triggered(clue_id: String)

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
	
	# 添加到clue_triggers组
	add_to_group("clue_triggers")
	
	# 检查是否已收集过（如果是一次性的）
	if one_time_only and has_node("/root/ClueManager"):
		if ClueManager.has_clue(clue_id):
			# 如果已收集，隐藏触发区域
			visible = false
			print("[INFO] 线索已收集，隐藏触发区域: ", clue_id)
			return
	
	print("[INFO] 线索触发区域已初始化: ", clue_id, " 位置: ", global_position)

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
	
	# 设置字体颜色（线索用蓝色，区别于答题的黄色）
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))  # 淡蓝色
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
		print("[INFO] 玩家进入线索触发区域: ", clue_id)
		
		# 检查是否已收集过
		if has_node("/root/ClueManager"):
			if ClueManager.has_clue(clue_id):
				if hint_label:
					hint_label.text = "已收集"
					hint_label.add_theme_color_override("font_color", Color.GREEN)
					hint_label.visible = true
				return
		
		# 检查前置任务
		if required_quest != "":
			if not _check_required_quest():
				if hint_label:
					hint_label.text = "前置任务未完成"
					hint_label.add_theme_color_override("font_color", Color.RED)
					hint_label.visible = true
				return
		
		# 显示提示
		if hint_label:
			hint_label.text = hint_text
			hint_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
			hint_label.visible = true

func _on_body_exited(body: Node2D):
	"""玩家离开触发区域"""
	if body.is_in_group("player"):
		player_in_range = false
		print("[INFO] 玩家离开线索触发区域: ", clue_id)
		
		# 隐藏提示
		if hint_label:
			hint_label.visible = false

func _input(event: InputEvent):
	"""处理输入事件"""
	# 在触发区域内按E键触发线索收集
	# 注意：需要检查玩家是否正在交互（避免与NPC对话冲突）
	if player_in_range and event.is_action_pressed("ui_accept"):
		# 检查玩家是否正在与其他系统交互
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("get") and "is_interacting" in player:
			if player.is_interacting:
				return  # 如果正在交互，不触发线索收集
		
		# 检查是否已收集过
		if has_node("/root/ClueManager"):
			if ClueManager.has_clue(clue_id):
				show_message("你已经收集过这个线索了！")
				return
		
		# 检查前置任务
		if required_quest != "":
			if not _check_required_quest():
				show_message("请先完成前置任务！")
				return
		
		# 触发线索收集
		trigger_clue()

func trigger_clue():
	"""触发线索收集"""
	print("[INFO] 触发线索收集: ", clue_id)
	
	# 发送信号
	clue_triggered.emit(clue_id)
	
	# 收集线索
	if has_node("/root/ClueManager"):
		var collected = ClueManager.collect_clue(clue_id, false)  # 不跳过解锁检查
		if collected:
			print("[INFO] ✅ 成功收集线索: ", clue_id)
			
			# 显示收集成功提示
			show_collect_success()
			
			# 如果是一次性的，隐藏触发区域
			if one_time_only:
				await get_tree().create_timer(1.0).timeout  # 等待1秒后隐藏
				visible = false
				if hint_label:
					hint_label.visible = false
		else:
			print("[ERROR] 线索收集失败: ", clue_id)
			show_message("无法收集线索，请检查前置条件")
	else:
		print("[ERROR] ClueManager未找到，无法收集线索")

func _check_required_quest() -> bool:
	"""检查前置任务是否完成"""
	if required_quest == "":
		return true
	
	if not has_node("/root/QuestManager"):
		print("[WARN] QuestManager未找到，无法检查前置任务")
		return false
	
	return QuestManager.is_quest_completed(required_quest)

func show_collect_success():
	"""显示收集成功提示"""
	if hint_label:
		hint_label.text = "✓ 线索已收集"
		hint_label.add_theme_color_override("font_color", Color.GREEN)
		
		# ⭐ 显示线索收集奖励特效
		if has_node("/root/RewardEffectManager"):
			var clue_info = ClueManager.get_clue_info(clue_id)
			if clue_info.has("title"):
				RewardEffectManager.show_clue_reward(clue_info["title"])

func show_message(message: String):
	"""显示消息（临时实现，可以后续优化）"""
	print("[INFO] ", message)
	# 可以在这里添加更美观的消息显示
	if hint_label:
		var original_text = hint_label.text
		hint_label.text = message
		hint_label.add_theme_color_override("font_color", Color.YELLOW)
		await get_tree().create_timer(2.0).timeout
		hint_label.text = original_text
		hint_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))

