# 奖励效果管理器（Autoload）
extends Node

# 奖励效果队列（支持多个奖励效果排队显示）
var reward_queue: Array[Dictionary] = []
var is_showing_reward: bool = false

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

func _add_to_queue(reward_data: Dictionary):
	"""将奖励添加到队列"""
	reward_queue.append(reward_data)
	_process_queue()

func _process_queue():
	"""处理奖励队列"""
	if is_showing_reward or reward_queue.is_empty():
		return
	
	is_showing_reward = true
	var reward_data = reward_queue.pop_front()
	_show_reward(reward_data)

func _show_reward(reward_data: Dictionary):
	"""显示奖励效果"""
	# 创建或获取奖励UI实例
	if not reward_ui_instance:
		reward_ui_instance = REWARD_UI_SCENE.instantiate()
		get_tree().root.add_child(reward_ui_instance)
	
	# 获取当前章节
	var current_chapter = _get_current_chapter()
	
	# 显示奖励
	if reward_data["type"] == "keyword":
		reward_ui_instance.show_keyword_reward(reward_data["keyword"], current_chapter)
	elif reward_data["type"] == "quiz":
		var correct_count = reward_data.get("correct_count", 1)
		reward_ui_instance.show_quiz_reward(correct_count, current_chapter)
	
	# 等待奖励动画完成
	await reward_ui_instance.reward_finished
	
	# 继续处理队列
	is_showing_reward = false
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

