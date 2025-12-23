# 答题管理器（Autoload）
extends Node

# 已完成的答题记录
var completed_quizzes: Dictionary = {}

# 答题题库
var quiz_database: Dictionary = {
	"region1_bridge": {
		"title": "青年李白知识问答",
		"target_region": 2,  # 答对后解锁区域2
		"questions": [
			{
				"type": "story",  # 故事题
				"question": "李白25岁时离开四川，开始了什么？",
				"options": ["仗剑去国，辞亲远游", "入京求仕", "隐居山林", "游历江南"],
				"correct": 0
			},
			{
				"type": "story",
				"question": "李白青年时期主要游历了哪些地方？",
				"options": ["湖北、湖南、江苏、浙江", "长安、洛阳", "四川、贵州", "山东、河南"],
				"correct": 0
			},
			{
				"type": "story",
				"question": "李白在青年时期的主要目标是什么？",
				"options": ["求仕（寻求官职）", "隐居修行", "经商致富", "从军报国"],
				"correct": 0
			},
			{
				"type": "poem",  # 诗词题
				"question": "请补全诗句：床前明月光，______",
				"options": ["疑是地上霜", "举头望明月", "低头思故乡", "月是故乡明"],
				"correct": 0
			},
			{
				"type": "poem",
				"question": "请补全诗句：______，疑是银河落九天",
				"options": ["飞流直下三千尺", "日照香炉生紫烟", "遥看瀑布挂前川", "天门中断楚江开"],
				"correct": 0
			},
			{
				"type": "poem",
				"question": "请补全诗句：举头望明月，______",
				"options": ["低头思故乡", "疑是地上霜", "床前明月光", "月是故乡明"],
				"correct": 0
			},
			{
				"type": "poem",
				"question": "请补全诗句：日照香炉生紫烟，______",
				"options": ["遥看瀑布挂前川", "飞流直下三千尺", "疑是银河落九天", "天门中断楚江开"],
				"correct": 0
			}
		],
		"required_correct": 2,  # 需要答对2题
		"total_questions": 3  # 随机抽取3题
	}
}

func _ready():
	print("[INFO] 答题管理器已初始化")
	# ⭐ 不自动加载进度，每次游戏重启都重置答题进度
	# load_progress()
	completed_quizzes.clear()
	print("[INFO] 答题进度已重置（游戏重启）")

func is_quiz_completed(quiz_id: String) -> bool:
	"""检查答题是否已完成"""
	return completed_quizzes.get(quiz_id, false)

func complete_quiz(quiz_id: String):
	"""标记答题完成"""
	completed_quizzes[quiz_id] = true
	save_progress()
	print("[INFO] 答题已完成: ", quiz_id)

func get_quiz(quiz_id: String) -> Dictionary:
	"""获取答题内容"""
	return quiz_database.get(quiz_id, {})

func get_random_questions(quiz_id: String, count: int = 3) -> Array:
	"""随机抽取指定数量的题目"""
	var quiz = get_quiz(quiz_id)
	if quiz.is_empty():
		return []
	
	var all_questions = quiz.get("questions", [])
	if all_questions.size() <= count:
		return all_questions
	
	# 随机打乱并取前count个
	var shuffled = all_questions.duplicate()
	shuffled.shuffle()
	return shuffled.slice(0, count)

func save_progress():
	"""保存进度到本地文件"""
	var save_data = {
		"completed_quizzes": completed_quizzes
	}
	var file = FileAccess.open("user://quiz_progress.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("[INFO] 答题进度已保存")

func load_progress():
	"""从本地文件加载进度"""
	var file = FileAccess.open("user://quiz_progress.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			var data = json.data
			completed_quizzes = data.get("completed_quizzes", {})
			print("[INFO] 答题进度已加载: ", completed_quizzes.size(), " 个已完成")
		file.close()

