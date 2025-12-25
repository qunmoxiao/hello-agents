# 物品收集系统
extends Node

signal item_collected(item_id: String, count: int)

var collected_items: Dictionary = {}
var item_database: Dictionary = {}

func _ready():
	print("[INFO] 物品收集系统已初始化")
	load_item_database()
	
	# ⭐ 不自动加载进度，每次游戏重启都重置物品收集
	# load_progress()
	collected_items.clear()
	print("[INFO] 物品进度已重置（游戏重启）")

func load_item_database():
	"""加载物品数据库"""
	print("[DEBUG] 📂 开始加载物品数据库...")
	var file = FileAccess.open("res://data/items.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var file_content = file.get_as_text()
		var parse_result = json.parse(file_content)
		if parse_result == OK:
			item_database = json.data
			print("[INFO] ✅ 物品数据库已加载: ", item_database.size(), " 个物品")
			# 输出所有物品ID用于调试
			print("[DEBUG] 物品ID列表: ", item_database.keys())
			# 特别检查奖杯物品
			if "trophy_chapter1" in item_database:
				print("[DEBUG] ✅ trophy_chapter1 存在于数据库中")
			else:
				print("[ERROR] ❌ trophy_chapter1 不在数据库中")
			if "trophy_chapter2" in item_database:
				print("[DEBUG] ✅ trophy_chapter2 存在于数据库中")
			else:
				print("[ERROR] ❌ trophy_chapter2 不在数据库中")
			if "trophy_chapter3" in item_database:
				print("[DEBUG] ✅ trophy_chapter3 存在于数据库中")
			else:
				print("[ERROR] ❌ trophy_chapter3 不在数据库中")
		else:
			print("[ERROR] ❌ 物品数据库JSON解析失败，错误代码: ", parse_result)
			print("[DEBUG] JSON内容前100字符: ", file_content.substr(0, 100))
		file.close()
	else:
		print("[ERROR] ❌ 物品数据库文件不存在: res://data/items.json")

func collect_item(item_id: String, count: int = 1) -> bool:
	"""收集物品
	
	Args:
		item_id: 物品ID
		count: 数量（默认1）
	
	Returns:
		bool: 是否成功收集
	"""
	print("[DEBUG] 📦 尝试收集物品: ", item_id, " 数量: ", count)
	print("[DEBUG] 物品数据库大小: ", item_database.size())
	print("[DEBUG] 当前已收集物品: ", collected_items.keys())
	
	if item_id not in item_database:
		print("[ERROR] ❌ 物品不存在于数据库中: ", item_id)
		print("[DEBUG] 数据库中的物品ID列表: ", item_database.keys())
		return false
	
	var item = item_database[item_id]
	print("[DEBUG] 找到物品: ", item.get("name", "未知"))
	
	# 检查是否可收集
	if not item.get("collectible", true):
		print("[WARN] ⚠️ 物品不可收集: ", item_id)
		return false
	
	# 检查是否可堆叠
	var stackable = item.get("stackable", false)
	if stackable:
		if item_id in collected_items:
			collected_items[item_id] += count
			print("[DEBUG] 堆叠物品，数量更新为: ", collected_items[item_id])
		else:
			collected_items[item_id] = count
			print("[DEBUG] 新收集堆叠物品，数量: ", count)
	else:
		# 不可堆叠物品，只能有一个
		if item_id in collected_items:
			print("[WARN] ⚠️ 物品已收集且不可堆叠: ", item_id)
			return false
		collected_items[item_id] = 1
		print("[DEBUG] 收集不可堆叠物品")
	
	print("[DEBUG] 发送 item_collected 信号: ", item_id, " x", count)
	item_collected.emit(item_id, count)
	
	print("[INFO] ✅ 收集到物品: ", item["name"], " x", count)
	print("[DEBUG] 当前背包物品: ", collected_items.keys())
	
	save_progress()
	
	# 检查收集任务进度
	_check_collection_quests(item_id)
	
	return true

func _check_collection_quests(item_id: String):
	"""检查收集任务进度"""
	if not has_node("/root/QuestManager"):
		return
	
	var active_quests = QuestManager.get_active_quests()
	for quest_id in active_quests:
		QuestManager.update_quest_progress(quest_id, -1, "", item_id)

func has_item(item_id: String, count: int = 1) -> bool:
	"""检查是否拥有足够数量的物品"""
	return collected_items.get(item_id, 0) >= count

func get_item_count(item_id: String) -> int:
	"""获取物品数量"""
	return collected_items.get(item_id, 0)

func get_all_items() -> Dictionary:
	"""获取所有物品（返回副本）"""
	return collected_items.duplicate()

func get_item_info(item_id: String) -> Dictionary:
	"""获取物品信息"""
	if item_id in item_database:
		return item_database[item_id]
	return {}

func get_collected_items_info() -> Array:
	"""获取所有已收集物品的详细信息"""
	var items_info = []
	for item_id in collected_items:
		if item_id in item_database:
			var item = item_database[item_id].duplicate()
			item["count"] = collected_items[item_id]
			items_info.append(item)
	return items_info

func save_progress():
	"""保存进度"""
	var save_data = {
		"items": collected_items
	}
	var file = FileAccess.open("user://item_inventory.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("[INFO] 物品进度已保存")
	else:
		print("[ERROR] 无法保存物品进度")

func load_progress():
	"""加载进度"""
	var file = FileAccess.open("user://item_inventory.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			collected_items = json.data.get("items", {})
			print("[INFO] 物品进度已加载: ", collected_items.size(), " 种物品")
		else:
			print("[ERROR] 物品进度JSON解析失败")
		file.close()
	else:
		print("[INFO] 物品进度文件不存在，使用新进度")

