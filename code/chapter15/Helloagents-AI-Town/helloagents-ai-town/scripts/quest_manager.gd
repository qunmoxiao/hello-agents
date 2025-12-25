# 任务管理器
extends Node

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_progress_updated(quest_id: String, progress: int, total: int)
signal chapter_completed(chapter: int, next_region: int)  # ⭐ 章节完成信号

var active_quests: Dictionary = {}
var completed_quests: Dictionary = {}
var quest_database: Dictionary = {}

# ⭐ WebSocket任务更新消息队列（确保所有消息都被处理）
var quest_update_queue: Array[Dictionary] = []
var is_processing_quest_updates: bool = false

func _ready():
	print("[INFO] 任务管理器已初始化")
	load_quest_database()
	
	# ⭐ 不自动加载进度，每次游戏重启都重置任务进度
	# load_progress()
	active_quests.clear()
	completed_quests.clear()
	print("[INFO] 任务进度已重置（游戏重启）")
	
	# 连接现有系统的信号
	_connect_existing_systems()
	
	# ⭐ 连接任务更新WebSocket信号
	call_deferred("_connect_quest_websocket")
	
	# ⭐ 重置后自动启动初始任务
	call_deferred("_auto_start_initial_quests")

func _connect_existing_systems():
	"""连接到现有系统的信号"""
	# 延迟连接，确保其他系统已初始化
	call_deferred("_connect_quiz_system")
	call_deferred("_connect_region_system")

func _connect_quiz_system():
	"""连接答题系统"""
	var quiz_ui = get_tree().get_first_node_in_group("quiz_ui")
	if quiz_ui:
		if not quiz_ui.quiz_completed.is_connected(_on_quiz_completed):
			quiz_ui.quiz_completed.connect(_on_quiz_completed)
			print("[INFO] 已连接到答题系统")
	else:
		# 如果还没找到，再延迟一次
		await get_tree().process_frame
		_connect_quiz_system()

func _connect_region_system():
	"""连接区域管理系统"""
	if has_node("/root/RegionManager"):
		if not RegionManager.region_unlocked.is_connected(_on_region_unlocked):
			RegionManager.region_unlocked.connect(_on_region_unlocked)
			print("[INFO] 已连接到区域管理系统")

func _connect_quest_websocket():
	"""连接任务更新WebSocket信号"""
	var api_client = get_node_or_null("/root/APIClient")
	if api_client:
		if not api_client.quest_update_received.is_connected(_on_quest_update_received):
			api_client.quest_update_received.connect(_on_quest_update_received)
			print("[INFO] 已连接到任务更新WebSocket")
	else:
		# 如果还没找到，再延迟一次
		await get_tree().process_frame
		_connect_quest_websocket()

func _on_quest_update_received(npc_name: String, quest_id: String, matched_keyword: String):
	"""处理来自WebSocket的任务更新
	Args:
		npc_name: NPC名称
		quest_id: 任务ID
		matched_keyword: 匹配到的关键词（主关键词）
	"""
	print("[INFO] 📡 收到外部对话任务更新: quest_id=", quest_id, ", keyword=", matched_keyword)
	
	# ⭐ 将消息加入队列，确保所有消息都被处理
	var update_data = {
		"npc_name": npc_name,
		"quest_id": quest_id,
		"matched_keyword": matched_keyword
	}
	quest_update_queue.append(update_data)
	print("[DEBUG] 📦 任务更新消息已加入队列: keyword=", matched_keyword, ", 队列长度=", quest_update_queue.size())
	
	# 处理队列
	_process_quest_update_queue()

func _process_quest_update_queue():
	"""处理任务更新队列，确保所有消息按顺序处理"""
	if is_processing_quest_updates or quest_update_queue.is_empty():
		return
	
	is_processing_quest_updates = true
	
	# 处理队列中的所有消息
	while not quest_update_queue.is_empty():
		var update_data = quest_update_queue.pop_front()
		var npc_name = update_data["npc_name"]
		var quest_id = update_data["quest_id"]
		var matched_keyword = update_data["matched_keyword"]
		
		print("[DEBUG] 🔄 处理队列中的任务更新: quest_id=", quest_id, ", keyword=", matched_keyword)
		
		# 检查任务是否存在且在进行中
		if quest_id not in active_quests:
			print("[WARN] 任务更新失败: 任务不存在或未激活 - ", quest_id)
			continue
		
		# 更新任务进度
		update_quest_progress(quest_id, -1, matched_keyword, "")
		
		# ⭐ 延迟一帧，确保奖励提示按顺序显示
		await get_tree().process_frame
	
	is_processing_quest_updates = false
	print("[DEBUG] ✅ 任务更新队列处理完成")

func load_quest_database():
	"""加载任务数据库"""
	var file = FileAccess.open("res://data/quests.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			quest_database = json.data
			print("[INFO] 任务数据库已加载: ", quest_database.size(), " 个任务")
		else:
			print("[ERROR] 任务数据库JSON解析失败")
		file.close()
	else:
		print("[WARN] 任务数据库文件不存在，将使用空数据库")

func start_quest(quest_id: String) -> bool:
	"""开始任务"""
	if quest_id not in quest_database:
		print("[ERROR] 任务不存在: ", quest_id)
		return false
	
	if quest_id in active_quests:
		print("[WARN] 任务已在进行中: ", quest_id)
		return false
	
	if quest_id in completed_quests:
		print("[WARN] 任务已完成: ", quest_id)
		return false
	
	# 检查前置任务
	var quest = quest_database[quest_id]
	var required_quests = quest.get("required_quests", [])
	for req_quest in required_quests:
		if req_quest not in completed_quests:
			print("[WARN] 前置任务未完成: ", req_quest)
			return false
	
	active_quests[quest_id] = {
		"quest": quest,
		"progress": 0,
		"started_at": Time.get_unix_time_from_system(),
		"collected_keywords": [],
		"collected_items": []
	}
	
	quest_started.emit(quest_id)
	print("[INFO] 任务开始: ", quest["title"])
	save_progress()
	return true

func update_quest_progress(quest_id: String, progress: int = -1, keyword = "", item_id: String = ""):
	"""更新任务进度
	
	Args:
		quest_id: 任务ID
		progress: 进度值（-1表示自动计算）
		keyword: 收集到的关键词（用于对话任务）
		item_id: 收集到的物品ID（用于收集任务）
	"""
	if quest_id not in active_quests:
		return
	
	var quest_data = active_quests[quest_id]
	var quest = quest_data["quest"]
	var quest_type = quest.get("type", "")
	
	# 根据任务类型更新进度
	match quest_type:
		"dialogue":
			# ⭐ 对话任务：检查关键词
			if keyword != "":
				# ⭐ 确保collected_keywords数组存在
				if not quest_data.has("collected_keywords"):
					quest_data["collected_keywords"] = []
				
				# ⭐ 检查关键词是否已收集
				var already_collected = keyword in quest_data["collected_keywords"]
				print("[DEBUG] 🔍 检查关键词: ", keyword, " 是否已收集: ", already_collected, " 已收集列表: ", quest_data["collected_keywords"])
				
				if not already_collected:
					quest_data["collected_keywords"].append(keyword)
					var collected_count = quest_data["collected_keywords"].size()
					# ⭐ 获取required_keywords，如果不存在则使用默认值1
					var required_count = quest.get("required_keywords", 1)
					
					# ⭐ 同步更新progress字段（确保数据一致性）
					quest_data["progress"] = collected_count
					
					print("[INFO] ✅ 任务进度更新: ", quest_id, " 关键词: ", keyword, " 进度: ", collected_count, "/", required_count, " collected_keywords=", quest_data["collected_keywords"])
					
					# ⭐ 显示关键词收集奖励效果
					# ⭐ 确保只传递主关键词（字符串），而不是数组
					var keyword_to_show: String = ""
					
					# 使用 typeof 检查类型，更安全
					var keyword_type = typeof(keyword)
					if keyword_type == TYPE_ARRAY:
						# 如果是数组，只取第一个元素
						var keyword_array = keyword as Array
						if keyword_array.size() > 0:
							keyword_to_show = str(keyword_array[0])
							print("[WARN] QuestManager 收到数组类型的关键词，提取主关键词: ", keyword_to_show)
						else:
							keyword_to_show = ""
					else:
						# 如果是字符串或其他类型，转换为字符串
						keyword_to_show = str(keyword)
					
					if has_node("/root/RewardEffectManager") and keyword_to_show != "":
						print("[DEBUG] 🎁 准备显示奖励提示: keyword=", keyword_to_show)
						RewardEffectManager.show_keyword_reward(keyword_to_show)
					else:
						print("[DEBUG] ⚠️ 无法显示奖励提示: RewardEffectManager=", has_node("/root/RewardEffectManager"), ", keyword_to_show=", keyword_to_show)
					
					# ⭐ 发送进度更新信号
					quest_progress_updated.emit(quest_id, collected_count, required_count)
					
					if collected_count >= required_count:
						print("[INFO] 🎉 任务完成条件满足: ", quest_id)
						complete_quest(quest_id)
				else:
					print("[INFO] ⚠️ 关键词已收集，跳过: ", quest_id, " 关键词: ", keyword)
		
		"quiz":
			# 答题任务：由答题系统触发
			pass
		
		"collection":
			# 收集任务：检查物品
			if item_id != "" and item_id not in quest_data["collected_items"]:
				quest_data["collected_items"].append(item_id)
				var required_items = quest.get("items", [])
				var collected_count = quest_data["collected_items"].size()
				var required_count = quest.get("required_count", required_items.size())
				quest_data["progress"] = collected_count
				quest_progress_updated.emit(quest_id, collected_count, required_count)
				
				if collected_count >= required_count:
					complete_quest(quest_id)
		
		_:
			# 其他类型：直接设置进度
			if progress >= 0:
				var total = quest.get("required_count", 1)
				quest_data["progress"] = progress
				quest_progress_updated.emit(quest_id, progress, total)
				
				if progress >= total:
					complete_quest(quest_id)

func complete_quest(quest_id: String):
	"""完成任务"""
	if quest_id not in active_quests:
		return
	
	var quest_data = active_quests[quest_id]
	var quest = quest_data["quest"]
	var chapter = quest.get("chapter", 1)
	var quest_type = quest.get("type", "")
	
	# ⭐ 确保进度达到完成要求（用于测试功能等直接完成的情况）
	var current_progress = quest_data.get("progress", 0)
	match quest_type:
		"dialogue":
			var required_keywords = quest.get("required_keywords", 1)
			if current_progress < required_keywords:
				quest_data["progress"] = required_keywords
				quest_progress_updated.emit(quest_id, required_keywords, required_keywords)
		"quiz":
			var required_correct = quest.get("required_correct", 1)
			if current_progress < required_correct:
				quest_data["progress"] = required_correct
				quest_progress_updated.emit(quest_id, required_correct, required_correct)
		"collection":
			var required_count = quest.get("required_count", 1)
			if current_progress < required_count:
				quest_data["progress"] = required_count
				quest_progress_updated.emit(quest_id, required_count, required_count)
	
	# 发放奖励
	var reward = quest.get("reward", {})
	
	# 发放线索
	if reward.has("clue"):
		if has_node("/root/ClueManager"):
			ClueManager.collect_clue(reward["clue"])
		else:
			print("[WARN] ClueManager未找到，无法发放线索奖励")
	
	# 发放经验值（如果有经验系统）
	if reward.has("exp"):
		# TODO: 集成经验系统
		print("[INFO] 获得经验值: ", reward["exp"])
	
	# 发放物品
	if reward.has("items"):
		if has_node("/root/ItemCollection"):
			for item_id in reward["items"]:
				ItemCollection.collect_item(item_id)
		else:
			print("[WARN] ItemCollection未找到，无法发放物品奖励")
	
	# ⭐ 注意：区域解锁延迟到场景所有任务完成后
	
	# 完成任务
	completed_quests[quest_id] = quest_data
	active_quests.erase(quest_id)
	
	quest_completed.emit(quest_id)
	print("[INFO] 任务完成: ", quest["title"])
	save_progress()
	
	# ⭐ 检查并启动下一个任务
	_start_next_quest(quest_id, chapter)
	
	# ⭐ 检查当前场景是否所有任务都完成，如果是则解锁下一场景
	_check_chapter_completion(chapter)

func _start_next_quest(completed_quest_id: String, chapter: int):
	"""启动下一个任务（任务链系统）
	
	Args:
		completed_quest_id: 刚完成的任务ID
		chapter: 当前章节
	"""
	# 方法1：查找以前置任务为刚完成任务的新任务
	for quest_id in quest_database:
		if quest_id in active_quests or quest_id in completed_quests:
			continue
		
		var quest = quest_database[quest_id]
		var quest_chapter = quest.get("chapter", 1)
		
		# 只检查同一章节的任务
		if quest_chapter != chapter:
			continue
		
		var required_quests = quest.get("required_quests", [])
		
		# 检查刚完成的任务是否在前置任务列表中
		if completed_quest_id in required_quests:
			# 检查所有前置任务是否都已完成
			var can_start = true
			for req_quest in required_quests:
				if req_quest not in completed_quests:
					can_start = false
					break
			
			if can_start:
				start_quest(quest_id)
				print("[INFO] 🔗 自动启动下一个任务: ", quest.get("title", quest_id))
				return
	
	# 方法2：如果没有找到直接关联的任务，检查是否有自动开始的任务
	_check_auto_start_quests_in_chapter(chapter)

func _check_auto_start_quests_in_chapter(chapter: int):
	"""检查指定章节是否有新任务可以自动开始"""
	for quest_id in quest_database:
		if quest_id in active_quests or quest_id in completed_quests:
			continue
		
		var quest = quest_database[quest_id]
		var quest_chapter = quest.get("chapter", 1)
		
		# 只检查同一章节的任务
		if quest_chapter != chapter:
			continue
		
		var trigger = quest.get("trigger", {})
		
		# 检查自动开始条件
		if trigger.get("auto_start", false):
			# 检查前置任务
			var required_quests = quest.get("required_quests", [])
			var can_start = true
			for req_quest in required_quests:
				if req_quest not in completed_quests:
					can_start = false
					break
			
			if can_start:
				start_quest(quest_id)
				print("[INFO] 🔗 自动启动任务: ", quest.get("title", quest_id))

func _check_auto_start_quests():
	"""检查是否有新任务可以自动开始（保留用于游戏开始时）"""
	for quest_id in quest_database:
		if quest_id in active_quests or quest_id in completed_quests:
			continue
		
		var quest = quest_database[quest_id]
		var trigger = quest.get("trigger", {})
		
		# 检查自动开始条件
		if trigger.get("auto_start", false):
			# 检查前置任务
			var required_quests = quest.get("required_quests", [])
			var can_start = true
			for req_quest in required_quests:
				if req_quest not in completed_quests:
					can_start = false
					break
			
			if can_start:
				start_quest(quest_id)

func _on_quiz_completed(quiz_id: String, passed: bool):
	"""答题完成回调"""
	if not passed:
		return
	
	# 查找相关的答题任务
	for quest_id in active_quests:
		var quest_data = active_quests[quest_id]
		var quest = quest_data["quest"]
		
		if quest.get("type") == "quiz" and quest.get("quiz_id") == quiz_id:
			# ⭐ 答题任务直接完成（答题系统已经验证了通过条件）
			complete_quest(quest_id)
			break

func _check_chapter_completion(chapter: int):
	"""检查当前章节是否所有任务都完成，如果是则解锁下一场景
	
	Args:
		chapter: 当前章节编号
	"""
	# 获取当前章节的所有任务
	var chapter_quests = []
	for quest_id in quest_database:
		var quest = quest_database[quest_id]
		var quest_chapter = quest.get("chapter", 1)
		var is_main = quest.get("is_main", false)
		
		# 只检查主任务（is_main: true）
		if quest_chapter == chapter and is_main:
			chapter_quests.append(quest_id)
	
	if chapter_quests.is_empty():
		print("[WARN] 章节 ", chapter, " 没有主任务")
		return
	
	# 检查所有主任务是否都已完成
	var all_completed = true
	for quest_id in chapter_quests:
		if quest_id not in completed_quests:
			all_completed = false
			break
	
	if all_completed:
		print("[INFO] 🎉 章节 ", chapter, " 所有主任务已完成！")
		
		# 查找最后一个完成的任务，获取区域解锁奖励
		var unlock_region_id = null
		for quest_id in chapter_quests:
			var quest = quest_database[quest_id]
			var reward = quest.get("reward", {})
			if reward.has("unlock_region"):
				unlock_region_id = reward["unlock_region"]
		
		# 解锁下一场景
		if unlock_region_id != null:
			if has_node("/root/RegionManager"):
				RegionManager.unlock_region(unlock_region_id)
				print("[INFO] ✅ 解锁下一场景: 区域 ", unlock_region_id)
				
				# ⭐ 发送章节完成信号
				chapter_completed.emit(chapter, unlock_region_id)
				
				# ⭐ 自动启动下一章节的初始任务
				call_deferred("_start_next_chapter_quests", chapter + 1)
			else:
				print("[WARN] RegionManager未找到，无法解锁区域")
		else:
			print("[INFO] 章节 ", chapter, " 完成，但没有配置区域解锁奖励")
	else:
		# 显示剩余任务数量
		var remaining_count = 0
		for quest_id in chapter_quests:
			if quest_id not in completed_quests:
				remaining_count += 1
		print("[INFO] 章节 ", chapter, " 还有 ", remaining_count, " 个任务未完成")

func _start_next_chapter_quests(next_chapter: int):
	"""启动下一章节的初始任务"""
	print("[INFO] 🔍 检查章节 ", next_chapter, " 的初始任务")
	
	var found_quests = []
	
	# 查找下一章节的所有任务
	for quest_id in quest_database:
		if quest_id in active_quests or quest_id in completed_quests:
			continue
		
		var quest = quest_database[quest_id]
		var quest_chapter = quest.get("chapter", 1)
		
		# 只检查下一章节的任务
		if quest_chapter != next_chapter:
			continue
		
		# 检查前置任务是否都已完成
		var required_quests = quest.get("required_quests", [])
		var can_start = true
		for req_quest in required_quests:
			if req_quest not in completed_quests:
				can_start = false
				break
		
		if can_start:
			found_quests.append({"quest_id": quest_id, "quest": quest})
	
	if found_quests.is_empty():
		print("[INFO] ⚠️ 章节 ", next_chapter, " 没有可启动的任务")
		# ⭐ 检查是否有章节2的任务（用于调试）
		var chapter2_quests = []
		for quest_id in quest_database:
			var quest = quest_database[quest_id]
			if quest.get("chapter", 1) == next_chapter:
				chapter2_quests.append(quest_id)
		if chapter2_quests.is_empty():
			print("[INFO] ℹ️ 数据库中确实没有章节 ", next_chapter, " 的任务")
		else:
			print("[INFO] ⚠️ 章节 ", next_chapter, " 有 ", chapter2_quests.size(), " 个任务，但前置条件未满足")
		return
	
	# 优先启动自动开始的任务
	var auto_start_quests = []
	var normal_quests = []
	
	for quest_info in found_quests:
		var quest = quest_info["quest"]
		var trigger = quest.get("trigger", {})
		if trigger.get("auto_start", false):
			auto_start_quests.append(quest_info)
		else:
			normal_quests.append(quest_info)
	
	# 先启动自动开始的任务
	for quest_info in auto_start_quests:
		start_quest(quest_info["quest_id"])
		print("[INFO] 🔗 自动启动下一章节任务: ", quest_info["quest"].get("title", quest_info["quest_id"]))
	
	# 如果没有自动开始的任务，启动第一个可以启动的任务
	if auto_start_quests.is_empty() and normal_quests.size() > 0:
		var quest_info = normal_quests[0]
		start_quest(quest_info["quest_id"])
		print("[INFO] 🔗 启动下一章节任务: ", quest_info["quest"].get("title", quest_info["quest_id"]))

func _on_region_unlocked(region_id: int):
	"""区域解锁回调"""
	print("[INFO] 区域解锁: ", region_id)
	# 可以在这里触发区域相关的任务

func save_progress():
	"""保存进度"""
	var save_data = {
		"active_quests": {},
		"completed_quests": {}
	}
	
	# 保存进行中的任务（只保存必要信息）
	for quest_id in active_quests:
		var quest_data = active_quests[quest_id]
		save_data["active_quests"][quest_id] = {
			"progress": quest_data["progress"],
			"started_at": quest_data["started_at"],
			"collected_keywords": quest_data["collected_keywords"],
			"collected_items": quest_data["collected_items"]
		}
	
	# 保存已完成的任务（只保存ID）
	save_data["completed_quests"] = completed_quests.keys()
	
	var file = FileAccess.open("user://quest_progress.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("[INFO] 任务进度已保存")
	else:
		print("[ERROR] 无法保存任务进度")

func load_progress():
	"""加载进度"""
	var file = FileAccess.open("user://quest_progress.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			var data = json.data
			var loaded_completed = data.get("completed_quests", [])
			
			# 恢复已完成任务列表
			for quest_id in loaded_completed:
				if quest_id in quest_database:
					completed_quests[quest_id] = {}
			
			# 恢复进行中的任务
			var loaded_active = data.get("active_quests", {})
			for quest_id in loaded_active:
				if quest_id in quest_database:
					var quest = quest_database[quest_id]
					var saved_data = loaded_active[quest_id]
					active_quests[quest_id] = {
						"quest": quest,
						"progress": saved_data.get("progress", 0),
						"started_at": saved_data.get("started_at", Time.get_unix_time_from_system()),
						"collected_keywords": saved_data.get("collected_keywords", []),
						"collected_items": saved_data.get("collected_items", [])
					}
			
			print("[INFO] 任务进度已加载: ", completed_quests.size(), " 个已完成, ", active_quests.size(), " 个进行中")
		else:
			print("[ERROR] 任务进度JSON解析失败")
		file.close()
	else:
		print("[INFO] 任务进度文件不存在，使用新进度")
	
	# 加载完成后，检查并自动启动初始任务
	call_deferred("_auto_start_initial_quests")

func get_active_quests() -> Array:
	"""获取当前进行中的任务ID列表"""
	return active_quests.keys()

func get_active_quest_data(quest_id: String) -> Dictionary:
	"""获取进行中任务的详细信息"""
	return active_quests.get(quest_id, {})

func is_quest_completed(quest_id: String) -> bool:
	"""检查任务是否已完成"""
	return quest_id in completed_quests

func is_quest_active(quest_id: String) -> bool:
	"""检查任务是否正在进行中"""
	return quest_id in active_quests

func get_quest_info(quest_id: String) -> Dictionary:
	"""获取任务信息"""
	return quest_database.get(quest_id, {})

func get_quest_database() -> Dictionary:
	"""获取任务数据库（供外部访问）"""
	return quest_database

func _auto_start_initial_quests():
	"""自动启动初始任务（游戏开始时）"""
	# 等待一帧，确保所有系统都已初始化
	await get_tree().process_frame
	
	# 查找所有自动开始的任务
	for quest_id in quest_database:
		var quest = quest_database[quest_id]
		var trigger = quest.get("trigger", {})
		
		# 检查是否是自动开始的任务
		if trigger.get("auto_start", false):
			# 检查前置任务
			var required_quests = quest.get("required_quests", [])
			var can_start = true
			for req_quest in required_quests:
				if req_quest not in completed_quests:
					can_start = false
					break
			
			# 如果任务还没开始且还没完成，则启动
			if can_start and quest_id not in active_quests and quest_id not in completed_quests:
				start_quest(quest_id)
				print("[INFO] 自动启动初始任务: ", quest.get("title", quest_id))
