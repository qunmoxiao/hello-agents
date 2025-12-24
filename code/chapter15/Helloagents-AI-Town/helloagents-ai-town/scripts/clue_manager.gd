# 线索管理器
extends Node

signal clue_collected(clue_id: String)

var collected_clues: Array = []
var clue_database: Dictionary = {}

func _ready():
	print("[INFO] 线索管理器已初始化")
	load_clue_database()
	
	# ⭐ 不自动加载进度，每次游戏重启都重置线索收集
	# load_progress()
	collected_clues.clear()
	print("[INFO] 线索进度已重置（游戏重启）")

func load_clue_database():
	"""加载线索数据库"""
	var file = FileAccess.open("res://data/clues.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			clue_database = json.data
			print("[INFO] 线索数据库已加载: ", clue_database.size(), " 个线索")
		else:
			print("[ERROR] 线索数据库JSON解析失败")
		file.close()
	else:
		print("[WARN] 线索数据库文件不存在，将使用空数据库")

func collect_clue(clue_id: String) -> bool:
	"""收集线索
	
	Returns:
		bool: 是否成功收集（新收集返回true，已收集返回false）
	"""
	if clue_id in collected_clues:
		print("[WARN] 线索已收集: ", clue_id)
		return false
	
	if clue_id not in clue_database:
		print("[ERROR] 线索不存在: ", clue_id)
		return false
	
	# 检查解锁条件
	var clue = clue_database[clue_id]
	var unlock_condition = clue.get("unlock_condition", {})
	if unlock_condition.has("type"):
		match unlock_condition["type"]:
			"quest_completion":
				var required_quest = unlock_condition.get("quest_id", "")
				if required_quest != "":
					if has_node("/root/QuestManager"):
						if not QuestManager.is_quest_completed(required_quest):
							print("[WARN] 前置任务未完成，无法收集线索: ", clue_id)
							return false
	
	collected_clues.append(clue_id)
	clue_collected.emit(clue_id)
	
	print("[INFO] 收集到线索: ", clue["title"])
	save_progress()
	return true

func has_clue(clue_id: String) -> bool:
	"""检查是否拥有线索"""
	return clue_id in collected_clues

func get_all_clues() -> Array:
	"""获取所有收集的线索ID列表"""
	return collected_clues.duplicate()

func get_clue_info(clue_id: String) -> Dictionary:
	"""获取线索信息"""
	if clue_id in clue_database:
		return clue_database[clue_id]
	return {}

func get_collected_clues_info() -> Array:
	"""获取所有已收集线索的详细信息"""
	var clues_info = []
	for clue_id in collected_clues:
		if clue_id in clue_database:
			clues_info.append(clue_database[clue_id])
	return clues_info

func save_progress():
	"""保存进度"""
	var save_data = {
		"clues": collected_clues
	}
	var file = FileAccess.open("user://clue_collection.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("[INFO] 线索进度已保存")
	else:
		print("[ERROR] 无法保存线索进度")

func load_progress():
	"""加载进度"""
	var file = FileAccess.open("user://clue_collection.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			collected_clues = json.data.get("clues", [])
			print("[INFO] 线索进度已加载: ", collected_clues.size(), " 个线索")
		else:
			print("[ERROR] 线索进度JSON解析失败")
		file.close()
	else:
		print("[INFO] 线索进度文件不存在，使用新进度")

