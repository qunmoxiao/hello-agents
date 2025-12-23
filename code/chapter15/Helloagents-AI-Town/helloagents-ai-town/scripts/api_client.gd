# API客户端 - 与FastAPI后端通信
extends Node

# 信号定义
signal chat_response_received(npc_name: String, message: String)
signal chat_error(error_message: String)
signal npc_status_received(dialogues: Dictionary)
signal npc_list_received(npcs: Array)
signal quiz_generated(quiz_id: String, quiz_data: Dictionary)
signal quiz_generation_failed(quiz_id: String, error_message: String)

# HTTP请求节点
var http_chat: HTTPRequest
var http_status: HTTPRequest
var http_npcs: HTTPRequest
var http_quiz: HTTPRequest

func _ready():
	# 创建HTTP请求节点
	http_chat = HTTPRequest.new()
	http_status = HTTPRequest.new()
	http_npcs = HTTPRequest.new()
	http_quiz = HTTPRequest.new()
	
	add_child(http_chat)
	add_child(http_status)
	add_child(http_npcs)
	add_child(http_quiz)
	
	# 连接信号
	http_chat.request_completed.connect(_on_chat_request_completed)
	http_status.request_completed.connect(_on_status_request_completed)
	http_npcs.request_completed.connect(_on_npcs_request_completed)
	http_quiz.request_completed.connect(_on_quiz_request_completed)
	
	print("[INFO] API客户端初始化完成")

# ==================== 对话API ====================
func send_chat(npc_name: String, message: String) -> void:
	"""发送对话请求"""
	var data = {
		"npc_name": npc_name,
		"message": message
	}
	
	var json_string = JSON.stringify(data)
	var headers = ["Content-Type: application/json"]
	
	print("[API] POST /chat -> ", data)
	
	var error = http_chat.request(
		Config.API_CHAT,
		headers,
		HTTPClient.METHOD_POST,
		json_string
	)
	
	if error != OK:
		print("[ERROR] 发送对话请求失败: ", error)
		chat_error.emit("网络请求失败")

func _on_chat_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	"""处理对话响应"""
	if response_code != 200:
		print("[ERROR] 对话请求失败: HTTP ", response_code)
		chat_error.emit("服务器错误: " + str(response_code))
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		print("[ERROR] 解析响应失败")
		chat_error.emit("响应解析失败")
		return
	
	var response = json.data
	
	if response.has("success") and response["success"]:
		var npc_name = response["npc_name"]
		var msg = response["message"]
		print("[INFO] 收到NPC回复: ", npc_name, " -> ", msg)
		chat_response_received.emit(npc_name, msg)
	else:
		chat_error.emit("对话失败")

# ==================== NPC状态API ====================
func get_npc_status() -> void:
	"""获取NPC状态"""
	# 检查是否正在处理请求
	if http_status.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("[WARN] NPC状态请求正在处理中,跳过本次请求")
		return

	print("[API] GET /npcs/status")

	var error = http_status.request(Config.API_NPC_STATUS)

	if error != OK:
		print("[ERROR] 获取NPC状态失败: ", error)

func _on_status_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	"""处理NPC状态响应"""
	if response_code != 200:
		print("[ERROR] NPC状态请求失败: HTTP ", response_code)
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		print("[ERROR] 解析NPC状态失败")
		return
	
	var response = json.data
	
	if response.has("dialogues"):
		var dialogues = response["dialogues"]
		print("[INFO] 收到NPC状态更新: ", dialogues.size(), "个NPC")
		npc_status_received.emit(dialogues)

# ==================== NPC列表API ====================
func get_npc_list() -> void:
	"""获取NPC列表"""
	print("[API] GET /npcs")
	
	var error = http_npcs.request(Config.API_NPCS)
	
	if error != OK:
		print("[ERROR] 获取NPC列表失败: ", error)

func _on_npcs_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	"""处理NPC列表响应"""
	if response_code != 200:
		print("[ERROR] NPC列表请求失败: HTTP ", response_code)
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		print("[ERROR] 解析NPC列表失败")
		return
	
	var response = json.data
	
	if response.has("npcs"):
		var npcs = response["npcs"]
		print("[INFO] 收到NPC列表: ", npcs.size(), "个NPC")
		npc_list_received.emit(npcs)

# ==================== 动态答题API ====================
func get_generated_quiz(quiz_id: String, npc_name: String, count: int = 3) -> void:
	"""获取指定 NPC 的动态题目"""
	# 避免并发请求
	if http_quiz.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("[WARN] 上一次动态答题请求尚未完成, 跳过本次请求")
		return
	
	var query_params = "?npc_name=" + npc_name.uri_encode() \
		+ "&count=" + str(count) \
		+ "&quiz_id=" + quiz_id.uri_encode()
	
	var url = Config.API_QUIZ_GENERATED + query_params
	print("[API] GET /quizzes/generated -> ", url)
	
	var error = http_quiz.request(url)
	if error != OK:
		print("[ERROR] 发送动态答题请求失败: ", error)
		quiz_generation_failed.emit(quiz_id, "网络请求失败")


func _on_quiz_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	"""处理动态答题响应"""
	if response_code != 200:
		print("[ERROR] 动态答题请求失败: HTTP ", response_code)
		quiz_generation_failed.emit("", "服务器错误: " + str(response_code))
		return
	
	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		print("[ERROR] 解析动态答题响应失败")
		quiz_generation_failed.emit("", "响应解析失败")
		return
	
	var response = json.data
	if not response is Dictionary:
		print("[ERROR] 动态答题响应格式错误")
		quiz_generation_failed.emit("", "响应格式错误")
		return
	
	var quiz_id := ""
	if response.has("quiz_id"):
		quiz_id = str(response["quiz_id"])
	
	if not response.has("questions") or not (response["questions"] is Array):
		print("[WARN] 动态答题返回的 questions 非法, 将回退本地题库")
		quiz_generation_failed.emit(quiz_id, "questions 非法")
		return
	
	print("[INFO] 收到动态题目: quiz_id=%s, questions=%d" % [quiz_id, response["questions"].size()])
	quiz_generated.emit(quiz_id, response)
