# 奖励效果管理器（Autoload）
extends Node

# 奖励效果队列（支持多个奖励效果排队显示）
var reward_queue: Array[Dictionary] = []
var is_showing_reward: bool = false

# ⭐ 公开队列和状态，供其他系统检查
func get_reward_queue() -> Array:
	"""获取奖励队列（只读）"""
	return reward_queue.duplicate()

# 奖励效果UI场景路径
const REWARD_UI_SCENE = preload("res://scenes/reward_effect_ui.tscn")

# 奖励效果UI实例
var reward_ui_instance: Node = null

func _ready():
	print("[INFO] 奖励效果管理器已初始化")

func show_keyword_reward(keyword):
	"""显示关键词收集奖励
	Args:
		keyword: 收集到的关键词（可能是字符串或数组，UI会处理）
	"""
	var reward_data = {
		"type": "keyword",
		"keyword": keyword
	}
	_add_to_queue(reward_data)

func show_quiz_reward(correct_count: int):
	"""显示答题正确奖励
	Args:
		correct_count: 已答对的题目数量
	"""
	var reward_data = {
		"type": "quiz",
		"correct_count": correct_count
	}
	_add_to_queue(reward_data)

func show_clue_reward(clue_title: String):
	"""显示线索收集奖励
	Args:
		clue_title: 收集到的线索标题
	"""
	var reward_data = {
		"type": "clue",
		"clue_title": clue_title
	}
	_add_to_queue(reward_data)

func show_achievement_reward(achievement_title: String, chapter: int, trophy_name: String = ""):
	"""显示成就奖励
	Args:
		achievement_title: 成就标题
		chapter: 章节号
		trophy_name: 奖杯名称（用于提示）
	"""
	var reward_data = {
		"type": "achievement",
		"achievement_title": achievement_title,
		"chapter": chapter,
		"trophy_name": trophy_name
	}
	_add_to_queue(reward_data)

func _add_to_queue(reward_data: Dictionary):
	"""将奖励添加到队列"""
	reward_queue.append(reward_data)
	var keyword = reward_data.get("keyword", "")
	print("[DEBUG] 🎁 奖励已加入队列: keyword=", keyword, ", 队列长度=", reward_queue.size(), ", 正在显示=", is_showing_reward)
	_process_queue()

func _process_queue():
	"""处理奖励队列"""
	if is_showing_reward or reward_queue.is_empty():
		if is_showing_reward:
			print("[DEBUG] 🎁 队列处理跳过: 正在显示奖励, 队列长度=", reward_queue.size())
		return
	
	is_showing_reward = true
	var reward_data = reward_queue.pop_front()
	var keyword = reward_data.get("keyword", "")
	print("[DEBUG] 🎁 开始处理队列中的奖励: keyword=", keyword, ", 剩余队列长度=", reward_queue.size())
	_show_reward(reward_data)

func _show_reward(reward_data: Dictionary):
	"""显示奖励效果 - 确保一个提示完全消失后才显示下一个"""
	# 创建或获取奖励UI实例
	if not reward_ui_instance:
		reward_ui_instance = REWARD_UI_SCENE.instantiate()
		get_tree().root.add_child(reward_ui_instance)
	
	# 获取当前章节
	var current_chapter = _get_current_chapter()
	
	# ⭐ 显示奖励并等待完全完成（包括动画和状态重置）
	if reward_data["type"] == "keyword":
		await reward_ui_instance.show_keyword_reward(reward_data["keyword"], current_chapter)
		print("[DEBUG] 🎁 关键词奖励动画已完成: ", reward_data["keyword"])
	elif reward_data["type"] == "quiz":
		var correct_count = reward_data.get("correct_count", 1)
		await reward_ui_instance.show_quiz_reward(correct_count, current_chapter)
		print("[DEBUG] 🎁 答题奖励动画已完成: correct_count=", correct_count)
	elif reward_data["type"] == "clue":
		var clue_title = reward_data.get("clue_title", "")
		reward_ui_instance.show_clue_reward(clue_title, current_chapter)
	elif reward_data["type"] == "achievement":
		var achievement_title = reward_data.get("achievement_title", "")
		var chapter = reward_data.get("chapter", current_chapter)
		var trophy_name = reward_data.get("trophy_name", "")
		reward_ui_instance.show_achievement_reward(achievement_title, chapter, trophy_name)
	
	# ⭐ 额外等待一帧，确保UI状态完全重置
	await get_tree().process_frame
	
	# 继续处理队列
	is_showing_reward = false
	print("[DEBUG] 🎁 奖励显示完成，继续处理队列，剩余队列长度=", reward_queue.size())
	_process_queue()

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
			if RegionManager:
				var unlocked_regions = RegionManager.unlocked_regions
				if unlocked_regions != null and unlocked_regions.size() > 0:
					return unlocked_regions[-1]  # 返回最大解锁区域
	return 1  # 默认返回章节1

