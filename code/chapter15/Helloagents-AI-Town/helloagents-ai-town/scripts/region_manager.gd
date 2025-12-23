# 区域管理器（Autoload）
extends Node

signal region_unlocked(region_id: int)

# 已解锁的区域
var unlocked_regions: Array[int] = [1]  # 初始只解锁区域1

# 区域边界配置（根据实际场景布局）
const REGION_BOUNDARIES = {
	1: {"left": 1080, "right": 3100},      # 区域1：青年时期场景
	2: {"left": 3100, "right": 4950},   # 区域2：中年时期场景
	3: {"left": 4950, "right": 6950}    # 区域3：老年时期场景
}

func _ready():
	print("[INFO] 区域管理器已初始化")
	# ⭐ 不自动加载进度，每次游戏重启都重置区域解锁
	# load_progress()
	unlocked_regions = [1]  # 重置为只解锁区域1
	print("[INFO] 区域解锁已重置（游戏重启），初始只解锁区域1")
	# 延迟更新摄像机限制，确保玩家节点已创建
	call_deferred("update_camera_limits")

func unlock_region(region_id: int):
	"""解锁区域"""
	if region_id not in unlocked_regions:
		unlocked_regions.append(region_id)
		unlocked_regions.sort()  # 排序
		region_unlocked.emit(region_id)
		update_camera_limits()
		save_progress()
		print("[INFO] ✅ 区域 %d 已解锁！" % region_id)
	else:
		print("[INFO] 区域 %d 已经解锁" % region_id)

func is_region_unlocked(region_id: int) -> bool:
	"""检查区域是否已解锁"""
	return region_id in unlocked_regions

func get_region_from_x(x: float) -> int:
	"""根据X坐标判断区域"""
	if x < REGION_BOUNDARIES[2]["left"]:
		return 1  # 区域1
	elif x < REGION_BOUNDARIES[3]["left"]:
		return 2  # 区域2
	else:
		return 3  # 区域3

func update_camera_limits():
	"""更新摄像机限制"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("[WARN] 未找到玩家节点，无法更新摄像机限制")
		return
	
	var camera = player.get_node_or_null("Camera2D")
	if not camera:
		print("[WARN] 玩家没有Camera2D节点，无法更新摄像机限制")
		return
	
	# 计算最大解锁的X坐标
	var max_x = 0
	if 1 in unlocked_regions:
		max_x = REGION_BOUNDARIES[1]["right"]
	if 2 in unlocked_regions:
		max_x = REGION_BOUNDARIES[2]["right"]
	if 3 in unlocked_regions:
		max_x = REGION_BOUNDARIES[3]["right"]
	
	# 更新摄像机限制
	camera.limit_right = max_x
	camera.limit_left = REGION_BOUNDARIES[1]["left"]
	
	print("[INFO] 摄像机右边界更新为: %d" % max_x)

func save_progress():
	"""保存进度到本地文件"""
	var save_data = {
		"unlocked_regions": unlocked_regions
	}
	var file = FileAccess.open("user://region_progress.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("[INFO] 区域进度已保存")

func load_progress():
	"""从本地文件加载进度"""
	var file = FileAccess.open("user://region_progress.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			var data = json.data
			var loaded_regions = data.get("unlocked_regions", [1])
			
			# 转换为Array[int]类型
			unlocked_regions.clear()
			for region_id in loaded_regions:
				if region_id is int:
					unlocked_regions.append(region_id)
				else:
					# 如果类型不对，尝试转换
					unlocked_regions.append(int(region_id))
			
			print("[INFO] 区域进度已加载: 解锁区域 ", unlocked_regions)
		file.close()
