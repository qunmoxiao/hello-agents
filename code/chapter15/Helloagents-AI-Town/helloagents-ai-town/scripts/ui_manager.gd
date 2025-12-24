# UI管理器 - 处理UI快捷键和切换
extends Node

# UI引用
var quest_ui: Node = null
var clue_ui: Node = null
var inventory_ui: Node = null

func _ready():
	# 延迟查找UI节点，确保场景树已完全初始化
	call_deferred("_find_ui_nodes")
	print("[INFO] UI管理器已初始化")

func _find_ui_nodes():
	"""查找UI节点"""
	# 方法1：通过组查找
	quest_ui = get_tree().get_first_node_in_group("quest_ui")
	clue_ui = get_tree().get_first_node_in_group("clue_ui")
	inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	
	# 方法2：如果组查找失败，尝试通过场景树查找
	if not quest_ui:
		quest_ui = get_tree().root.get_node_or_null("Main/QuestUI")
		if quest_ui:
			print("[INFO] 通过路径找到任务UI")
	
	if not clue_ui:
		clue_ui = get_tree().root.get_node_or_null("Main/ClueUI")
		if clue_ui:
			print("[INFO] 通过路径找到线索UI")
	
	if not inventory_ui:
		inventory_ui = get_tree().root.get_node_or_null("Main/InventoryUI")
		if inventory_ui:
			print("[INFO] 通过路径找到背包UI")
	
	# 方法3：遍历场景树查找
	if not quest_ui:
		quest_ui = _find_node_by_name(get_tree().root, "QuestUI")
	
	if not clue_ui:
		clue_ui = _find_node_by_name(get_tree().root, "ClueUI")
	
	if not inventory_ui:
		inventory_ui = _find_node_by_name(get_tree().root, "InventoryUI")
	
	# 打印结果
	print("[INFO] ========== UI节点查找结果 ==========")
	if quest_ui:
		print("[INFO] ✅ 找到任务UI: ", quest_ui.name, " (路径: ", quest_ui.get_path(), ")")
	else:
		print("[ERROR] ❌ 未找到任务UI")
	
	if clue_ui:
		print("[INFO] ✅ 找到线索UI: ", clue_ui.name, " (路径: ", clue_ui.get_path(), ")")
	else:
		print("[ERROR] ❌ 未找到线索UI")
	
	if inventory_ui:
		print("[INFO] ✅ 找到背包UI: ", inventory_ui.name, " (路径: ", inventory_ui.get_path(), ")")
	else:
		print("[ERROR] ❌ 未找到背包UI")
	print("[INFO] ====================================")
	
	# 如果还是找不到，再延迟一次
	if not quest_ui or not clue_ui or not inventory_ui:
		await get_tree().process_frame
		_find_ui_nodes()

func _find_node_by_name(node: Node, name: String) -> Node:
	"""递归查找节点"""
	if node.name == name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	return null

func _input(event: InputEvent):
	"""处理UI快捷键"""
	# 如果对话框正在打开，直接不处理任何UI快捷键（避免在聊天输入时误触 C/I 等）
	var dialogue_ui = get_tree().get_first_node_in_group("dialogue_system")
	if dialogue_ui and dialogue_ui.visible:
		return

	# 检查是否正在其他交互中（对话、答题等）
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get") and "is_interacting" in player:
		if player.is_interacting:
			# 检查是否正在使用UI
			if not (quest_ui and quest_ui.visible) and not (clue_ui and clue_ui.visible) and not (inventory_ui and inventory_ui.visible):
				return  # 如果正在其他交互中，不处理UI快捷键
	
	# Q键 - 任务UI已改为常驻显示，不再响应快捷键
	# if event.is_action_pressed("ui_quest") or (event is InputEventKey and event.pressed and event.keycode == KEY_Q):
	# 	_toggle_quest_ui()
	# 	get_viewport().set_input_as_handled()
	
	# C键 - 打开/关闭线索UI
	if event.is_action_pressed("ui_clue") or (event is InputEventKey and event.pressed and event.keycode == KEY_C):
		_toggle_clue_ui()
		get_viewport().set_input_as_handled()
	
	# I键 - 打开/关闭背包UI
	if event.is_action_pressed("ui_inventory") or (event is InputEventKey and event.pressed and event.keycode == KEY_I):
		_toggle_inventory_ui()
		get_viewport().set_input_as_handled()

func _toggle_quest_ui():
	"""切换任务UI"""
	# 如果还没找到，尝试再次查找
	if not quest_ui:
		_find_ui_nodes()
	
	if quest_ui:
		if quest_ui.visible:
			if quest_ui.has_method("hide_quest_ui"):
				quest_ui.hide_quest_ui()
			else:
				quest_ui.visible = false
		else:
			if quest_ui.has_method("show_quest_ui"):
				quest_ui.show_quest_ui()
			else:
				quest_ui.visible = true
	else:
		print("[ERROR] 任务UI未找到，无法打开")

func _toggle_clue_ui():
	"""切换线索UI"""
	# 如果还没找到，尝试再次查找
	if not clue_ui:
		_find_ui_nodes()
	
	if clue_ui:
		if clue_ui.visible:
			if clue_ui.has_method("hide_clue_ui"):
				clue_ui.hide_clue_ui()
			else:
				clue_ui.visible = false
		else:
			if clue_ui.has_method("show_clue_ui"):
				clue_ui.show_clue_ui()
			else:
				clue_ui.visible = true
	else:
		print("[ERROR] 线索UI未找到，无法打开")

func _toggle_inventory_ui():
	"""切换背包UI"""
	# 如果还没找到，尝试再次查找
	if not inventory_ui:
		_find_ui_nodes()
	
	if inventory_ui:
		if inventory_ui.visible:
			if inventory_ui.has_method("hide_inventory_ui"):
				inventory_ui.hide_inventory_ui()
			else:
				inventory_ui.visible = false
		else:
			if inventory_ui.has_method("show_inventory_ui"):
				inventory_ui.show_inventory_ui()
			else:
				inventory_ui.visible = true
	else:
		print("[ERROR] 背包UI未找到，无法打开")

