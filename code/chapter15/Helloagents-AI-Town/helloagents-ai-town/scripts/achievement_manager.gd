# 成就管理器
extends Node

signal achievement_unlocked(achievement_id: String)

var unlocked_achievements: Array = []
var achievement_database: Dictionary = {}

func _ready():
	print("[INFO] 成就管理器已初始化")
	load_achievement_database()
	# ⭐ 不自动加载进度，每次游戏重启都重置成就（与物品和线索系统保持一致）
	# load_progress()
	unlocked_achievements.clear()
	print("[INFO] 成就进度已重置（游戏重启）")

func load_achievement_database():
	"""加载成就数据库"""
	achievement_database = {
		"chapter1_clue_master": {
			"achievement_id": "chapter1_clue_master",
			"title": "青年时期的探索者",
			"description": "收集第一章所有线索",
			"chapter": 1,
			"type": "clue_collection",
			"required_clues": ["clue_001", "clue_002", "clue_101", "clue_102", "clue_103"],
			"reward_item": "trophy_chapter1"
		},
		"chapter2_clue_master": {
			"achievement_id": "chapter2_clue_master",
			"title": "长安时期的见证者",
			"description": "收集第二章所有线索",
			"chapter": 2,
			"type": "clue_collection",
			"required_clues": ["clue_003", "clue_004", "clue_201", "clue_202", "clue_203"],
			"reward_item": "trophy_chapter2"
		},
		"chapter3_clue_master": {
			"achievement_id": "chapter3_clue_master",
			"title": "晚年时期的记录者",
			"description": "收集第三章所有线索",
			"chapter": 3,
			"type": "clue_collection",
			"required_clues": ["clue_005", "clue_006", "clue_301", "clue_302", "clue_303"],
			"reward_item": "trophy_chapter3"
		}
	}
	print("[INFO] 成就数据库已加载: ", achievement_database.size(), " 个成就")

func _check_and_grant_missing_rewards():
	"""检查已解锁成就的奖励物品是否在背包中，如果不在则补发"""
	print("[DEBUG] 🔍 检查已解锁成就的奖励物品...")
	if not has_node("/root/ItemCollection"):
		print("[ERROR] ItemCollection未找到，无法检查奖励物品")
		return
	
	for achievement_id in unlocked_achievements:
		if achievement_id not in achievement_database:
			continue
		
		var achievement = achievement_database[achievement_id]
		var reward_item = achievement.get("reward_item", "")
		
		if reward_item != "":
			if not ItemCollection.has_item(reward_item):
				print("[DEBUG] ⚠️ 成就 ", achievement_id, " 的奖励物品 ", reward_item, " 不在背包中，补发...")
				var collected = ItemCollection.collect_item(reward_item)
				if collected:
					print("[INFO] ✅ 已补发奖励物品: ", reward_item)
				else:
					print("[ERROR] ❌ 补发奖励物品失败: ", reward_item)
			else:
				print("[DEBUG] ✅ 成就 ", achievement_id, " 的奖励物品 ", reward_item, " 已在背包中")

func check_chapter_clue_achievement(chapter: int):
	"""检查章节线索成就
	Args:
		chapter: 章节号（1, 2, 3）
	"""
	print("[DEBUG] 🔍 检查章节 ", chapter, " 的线索成就")
	
	if not has_node("/root/ClueManager"):
		print("[ERROR] ClueManager未找到，无法检查成就")
		return
	
	var achievement_id = "chapter%d_clue_master" % chapter
	print("[DEBUG] 成就ID: ", achievement_id)
	
	if achievement_id in unlocked_achievements:
		print("[DEBUG] 成就已解锁，跳过: ", achievement_id)
		return  # 已经解锁过了
	
	if achievement_id not in achievement_database:
		print("[ERROR] 成就不在数据库中: ", achievement_id)
		return
	
	var achievement = achievement_database[achievement_id]
	var required_clues = achievement.get("required_clues", [])
	print("[DEBUG] 需要收集的线索数量: ", required_clues.size(), " 线索列表: ", required_clues)
	
	# 检查是否收集了所有必需的线索
	var all_collected = true
	var collected_count = 0
	for clue_id in required_clues:
		if ClueManager.has_clue(clue_id):
			collected_count += 1
			print("[DEBUG] ✅ 已收集线索: ", clue_id)
		else:
			all_collected = false
			print("[DEBUG] ❌ 未收集线索: ", clue_id)
	
	print("[DEBUG] 线索收集进度: ", collected_count, "/", required_clues.size())
	
	if all_collected:
		print("[DEBUG] 🎉 所有线索已收集，解锁成就: ", achievement_id)
		unlock_achievement(achievement_id)
	else:
		print("[DEBUG] ⏳ 线索未全部收集，无法解锁成就")

func unlock_achievement(achievement_id: String):
	"""解锁成就"""
	if achievement_id in unlocked_achievements:
		return  # 已经解锁过了
	
	if achievement_id not in achievement_database:
		print("[ERROR] 成就不存在: ", achievement_id)
		return
	
	var achievement = achievement_database[achievement_id]
	unlocked_achievements.append(achievement_id)
	
	print("[INFO] 🏆 解锁成就: ", achievement["title"])
	
	# 发送信号
	achievement_unlocked.emit(achievement_id)
	
	# 发放奖励
	var reward_item = achievement.get("reward_item", "")
	print("[DEBUG] 🎁 奖励物品ID: ", reward_item)
	var trophy_name = ""
	if reward_item != "":
		if has_node("/root/ItemCollection"):
			print("[DEBUG] ItemCollection 存在，开始收集物品: ", reward_item)
			# 检查物品是否在数据库中
			var item_info_before = ItemCollection.get_item_info(reward_item)
			if item_info_before.is_empty():
				print("[ERROR] ❌ 物品不在数据库中: ", reward_item)
			else:
				print("[DEBUG] 物品信息: ", item_info_before)
			
			var collected = ItemCollection.collect_item(reward_item)
			print("[DEBUG] 物品收集结果: ", collected)
			
			if collected:
				# 获取奖杯名称用于显示
				var item_info = ItemCollection.get_item_info(reward_item)
				if item_info.has("name"):
					trophy_name = item_info["name"]
				print("[INFO] ✅ 成功获得奖励物品: ", reward_item, " (", trophy_name, ")")
				
				# 验证物品是否真的在背包中
				if ItemCollection.has_item(reward_item):
					print("[DEBUG] ✅ 验证：物品已在背包中")
				else:
					print("[ERROR] ❌ 验证失败：物品不在背包中")
			else:
				print("[ERROR] ❌ 物品收集失败: ", reward_item)
				# 输出详细错误信息
				if not ItemCollection.has_item(reward_item):
					print("[DEBUG] 物品确实不在背包中")
		else:
			print("[ERROR] ❌ ItemCollection未找到，无法发放奖励物品")
	else:
		print("[WARN] ⚠️ 成就没有奖励物品")
	
	# ⭐ 延迟显示成就奖励特效，确保在线索奖励之后显示
	# 等待奖励队列处理完成（确保线索奖励先显示）
	if has_node("/root/RewardEffectManager"):
		# 等待当前奖励显示完成，并且队列为空
		var reward_queue = RewardEffectManager.get_reward_queue()
		while RewardEffectManager.is_showing_reward or reward_queue.size() > 0:
			await get_tree().create_timer(0.1).timeout
			reward_queue = RewardEffectManager.get_reward_queue()
		
		# 再等待一小段时间，确保线索奖励动画完全结束
		await get_tree().create_timer(0.3).timeout
		
		# 显示成就奖励特效（现在会排在最后），传递奖杯名称
		RewardEffectManager.show_achievement_reward(achievement["title"], achievement.get("chapter", 1), trophy_name)
	
	save_progress()

func has_achievement(achievement_id: String) -> bool:
	"""检查是否拥有成就"""
	return achievement_id in unlocked_achievements

func get_achievement_info(achievement_id: String) -> Dictionary:
	"""获取成就信息"""
	if achievement_id in achievement_database:
		return achievement_database[achievement_id]
	return {}

func get_chapter_clue_progress(chapter: int) -> Dictionary:
	"""获取章节线索进度
	Returns:
		{"collected": int, "total": int, "percentage": float}
	"""
	if not has_node("/root/ClueManager"):
		return {"collected": 0, "total": 0, "percentage": 0.0}
	
	var achievement_id = "chapter%d_clue_master" % chapter
	if achievement_id not in achievement_database:
		return {"collected": 0, "total": 0, "percentage": 0.0}
	
	var achievement = achievement_database[achievement_id]
	var required_clues = achievement.get("required_clues", [])
	var total = required_clues.size()
	var collected = 0
	
	for clue_id in required_clues:
		if ClueManager.has_clue(clue_id):
			collected += 1
	
	var percentage = 0.0
	if total > 0:
		percentage = float(collected) / float(total) * 100.0
	
	return {
		"collected": collected,
		"total": total,
		"percentage": percentage
	}

func save_progress():
	"""保存进度"""
	var save_data = {
		"achievements": unlocked_achievements
	}
	var file = FileAccess.open("user://achievements.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("[INFO] 成就进度已保存")
	else:
		print("[ERROR] 无法保存成就进度")

func load_progress():
	"""加载进度"""
	var file = FileAccess.open("user://achievements.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			unlocked_achievements = json.data.get("achievements", [])
			print("[INFO] 成就进度已加载: ", unlocked_achievements.size(), " 个成就")
		else:
			print("[ERROR] 成就进度JSON解析失败")
		file.close()
	else:
		print("[INFO] 成就进度文件不存在，使用新进度")

