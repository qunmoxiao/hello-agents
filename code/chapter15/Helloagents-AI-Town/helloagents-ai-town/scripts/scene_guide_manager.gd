# 场景指南管理器
extends Node

signal guide_opened()
signal guide_closed()

var current_chapter: int = 1
var guide_data: Dictionary = {}
var guide_ui: Node = null

func _ready():
	print("[INFO] 场景指南管理器已初始化")
	load_guide_data()
	call_deferred("_find_guide_ui")
	
	# 连接区域管理器信号，检测章节变化
	if has_node("/root/RegionManager"):
		if not RegionManager.region_unlocked.is_connected(_on_region_unlocked):
			RegionManager.region_unlocked.connect(_on_region_unlocked)
			print("[INFO] 已连接到区域管理系统")

func load_guide_data():
	"""加载场景指南数据"""
	var file = FileAccess.open("res://data/scene_guides.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			guide_data = json.data
			print("[INFO] 场景指南数据已加载: ", guide_data.size(), " 个场景")
		else:
			print("[ERROR] 场景指南数据JSON解析失败: ", json.get_error_message())
		file.close()
	else:
		print("[WARN] 场景指南数据文件不存在")

func _find_guide_ui():
	"""查找场景指南UI"""
	# 方法1：通过组查找
	guide_ui = get_tree().get_first_node_in_group("scene_guide_ui")
	
	# 方法2：如果组查找失败，尝试通过场景树查找
	if not guide_ui:
		guide_ui = get_tree().root.get_node_or_null("Main/SceneGuideUI")
		if guide_ui:
			print("[INFO] 通过路径找到场景指南UI")
	
	# 方法3：遍历场景树查找
	if not guide_ui:
		guide_ui = _find_node_by_name(get_tree().root, "SceneGuideUI")
	
	if guide_ui:
		print("[INFO] ✅ 找到场景指南UI: ", guide_ui.name, " (路径: ", guide_ui.get_path(), ")")
	else:
		print("[WARN] ⚠️ 未找到场景指南UI，请确保场景已添加到主场景中")

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
	"""处理B键输入"""
	# 检查是否正在其他交互中（对话、答题等）
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get") and "is_interacting" in player:
		if player.is_interacting:
			# 如果正在交互，不处理指南快捷键（除非指南已打开）
			if not guide_ui or not guide_ui.visible:
				return
	
	if event.is_action_pressed("ui_guide") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B):
		toggle_guide()
		get_viewport().set_input_as_handled()

func toggle_guide():
	"""切换指南显示"""
	if not guide_ui:
		_find_guide_ui()
		if not guide_ui:
			return
	
	if guide_ui.visible:
		close_guide()
	else:
		open_guide()

func open_guide():
	"""打开场景指南"""
	if not guide_ui:
		return
	
	# 更新当前章节
	current_chapter = _get_current_chapter()
	
	# 更新指南内容
	if guide_ui.has_method("update_guide_content"):
		var chapter_key = "chapter_%d" % current_chapter
		var chapter_data = guide_data.get(chapter_key, {})
		guide_ui.update_guide_content(chapter_data)
	
	guide_ui.visible = true
	guide_opened.emit()
	print("[INFO] 打开场景指南，章节: ", current_chapter)

func close_guide():
	"""关闭场景指南"""
	if not guide_ui:
		return
	
	guide_ui.visible = false
	guide_closed.emit()
	print("[INFO] 关闭场景指南")

func _get_current_chapter() -> int:
	"""获取当前章节（根据玩家位置）"""
	# 区域1 = 章节1，区域2 = 章节2，区域3 = 章节3
	if has_node("/root/RegionManager"):
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var player_x = player.global_position.x
			var current_region = RegionManager.get_region_from_x(player_x)
			return current_region
		else:
			# 如果找不到玩家，根据解锁的区域判断
			var unlocked_regions = RegionManager.unlocked_regions
			if unlocked_regions.size() > 0:
				return unlocked_regions[-1]  # 返回最大解锁区域
	return 1  # 默认返回章节1

func _on_region_unlocked(region_id: int):
	"""区域解锁回调"""
	# 区域解锁时，可以显示新场景的指南提示
	print("[INFO] 区域解锁: ", region_id, "，可以查看新场景指南（按B键）")

