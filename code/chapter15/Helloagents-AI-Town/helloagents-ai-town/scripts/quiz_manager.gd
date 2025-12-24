# 答题管理器（Autoload）
extends Node

# 已完成的答题记录
var completed_quizzes: Dictionary = {}

# 动态题目缓存: quiz_id -> Array[Dictionary]
var dynamic_questions_cache: Dictionary = {}

# 答题题库
var quiz_database: Dictionary = {
	"region1_bridge": {
		"title": "青年李白知识问答",
		"npc_name": "青年李白",
		"target_region": 2,  # 答对后解锁区域2
		"fallback_questions": [
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
	},
	"region2_palace": {
		"title": "中年李白知识问答",
		"target_region": 3,  # 答对后解锁区域3
		"questions": [
			{
				"type": "story",
				"question": "李白在长安时期的主要经历是什么？",
				"options": ["进入翰林院，为皇帝写诗", "担任宰相", "从军征战", "隐居山林"],
				"correct": 0
			},
			{
				"type": "story",
				"question": "李白在长安时期与哪位贵妃关系密切？",
				"options": ["杨贵妃", "武则天", "王昭君", "西施"],
				"correct": 0
			},
			{
				"type": "story",
				"question": "李白离开长安的主要原因是什么？",
				"options": ["赐金放还", "被贬官", "主动辞职", "被流放"],
				"correct": 0
			},
			{
				"type": "poem",
				"question": "请补全诗句：______，千金散尽还复来",
				"options": ["天生我材必有用", "人生得意须尽欢", "烹羊宰牛且为乐", "钟鼓馔玉不足贵"],
				"correct": 0
			},
			{
				"type": "poem",
				"question": "请补全诗句：人生得意须尽欢，______",
				"options": ["莫使金樽空对月", "天生我材必有用", "千金散尽还复来", "烹羊宰牛且为乐"],
				"correct": 0
			},
			{
				"type": "poem",
				"question": "请补全诗句：______，疑是地上霜",
				"options": ["床前明月光", "举头望明月", "低头思故乡", "月是故乡明"],
				"correct": 0
			},
			{
				"type": "poem",
				"question": "请补全诗句：长风破浪会有时，______",
				"options": ["直挂云帆济沧海", "天生我材必有用", "千金散尽还复来", "人生得意须尽欢"],
				"correct": 0
			}
		],
		"required_correct": 2,  # 需要答对2题
		"total_questions": 3  # 随机抽取3题
	},
	"region3_dock": {
		"title": "老年李白知识问答",
		"target_region": 0,  # 已经是最后一个区域，不需要解锁
		"questions": [
			{
				"type": "story",
				"question": "李白晚年被流放到哪里？",
				"options": ["夜郎", "海南", "新疆", "西藏"],
				"correct": 0
			},
			{
				"type": "story",
				"question": "李白流放夜郎的原因是什么？",
				"options": ["参与永王李璘的叛乱", "得罪皇帝", "写诗讽刺朝廷", "贪污受贿"],
				"correct": 0
			},
			{
				"type": "story",
				"question": "李白最终在哪里去世？",
				"options": ["当涂", "长安", "四川", "江南"],
				"correct": 0
			},
			{
				"type": "poem",
				"question": "请补全诗句：______，千里江陵一日还",
				"options": ["朝辞白帝彩云间", "两岸猿声啼不住", "轻舟已过万重山", "孤帆远影碧空尽"],
				"correct": 0
			},
			{
				"type": "poem",
				"question": "请补全诗句：两岸猿声啼不住，______",
				"options": ["轻舟已过万重山", "朝辞白帝彩云间", "千里江陵一日还", "孤帆远影碧空尽"],
				"correct": 0
			},
			{
				"type": "poem",
				"question": "请补全诗句：______，唯见长江天际流",
				"options": ["孤帆远影碧空尽", "朝辞白帝彩云间", "两岸猿声啼不住", "轻舟已过万重山"],
				"correct": 0
			},
			{
				"type": "poem",
				"question": "请补全诗句：抽刀断水水更流，______",
				"options": ["举杯消愁愁更愁", "人生在世不称意", "明朝散发弄扁舟", "长风万里送秋雁"],
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
	
	# 若有动态题目缓存, 优先使用
	if dynamic_questions_cache.has(quiz_id):
		var dyn = dynamic_questions_cache[quiz_id]
		if dyn is Array and dyn.size() > 0:
			return dyn
	
	# 否则使用本地兜底题库
	var all_questions = []
	if quiz.has("questions"):
		all_questions = quiz.get("questions", [])
	else:
		all_questions = quiz.get("fallback_questions", [])
	if all_questions.size() <= count:
		return all_questions
	
	# 随机打乱并取前count个
	var shuffled = all_questions.duplicate()
	shuffled.shuffle()
	return shuffled.slice(0, count)


func set_dynamic_questions(quiz_id: String, questions: Array) -> void:
	"""设置某次答题触发的动态题目缓存"""
	if questions.is_empty():
		dynamic_questions_cache.erase(quiz_id)
	else:
		dynamic_questions_cache[quiz_id] = questions

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
