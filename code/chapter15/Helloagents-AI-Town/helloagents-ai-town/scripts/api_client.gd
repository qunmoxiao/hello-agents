# API客户端 - 与FastAPI后端通信
extends Node

# 信号定义
signal chat_response_received(npc_name: String, message: String, matched_keywords: Array)
signal chat_error(error_message: String)
signal npc_status_received(dialogues: Dictionary)
signal npc_list_received(npcs: Array)
signal quiz_generated(quiz_id: String, quiz_data: Dictionary)
signal quiz_generation_failed(quiz_id: String, error_message: String)
signal quest_update_received(npc_name: String, quest_id: String, matched_keyword: String)
signal external_dialogue_ws_status_received(status: String, message: String)  # ⭐ 外部对话WebSocket连接状态信号

# HTTP请求节点
var http_chat: HTTPRequest
var http_status: HTTPRequest
var http_npcs: HTTPRequest
var http_quiz: HTTPRequest

# WebSocket客户端（任务更新）
var quest_ws_client: WebSocketPeer = null
var quest_ws_connected: bool = false
var quest_ws_reconnect_timer: float = 0.0
const QUEST_WS_RECONNECT_INTERVAL = 5.0  # 重连间隔（秒）

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
	
	# ⭐ 初始化任务更新WebSocket客户端
	_init_quest_websocket()
	
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
		# ⭐ 获取后端语义匹配的关键词（如果存在）
		var matched_keywords = []
		if response.has("matched_keywords") and response["matched_keywords"] is Array:
			matched_keywords = response["matched_keywords"]
			print("[INFO] 后端语义匹配到关键词: ", matched_keywords)
		print("[INFO] 收到NPC回复: ", npc_name, " -> ", msg)
		chat_response_received.emit(npc_name, msg, matched_keywords)
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

# ==================== 任务更新WebSocket ====================
func _init_quest_websocket():
	"""初始化任务更新WebSocket客户端"""
	quest_ws_client = WebSocketPeer.new()
	_connect_quest_websocket()

func _connect_quest_websocket():
	"""连接到任务更新WebSocket"""
	if quest_ws_client == null:
		quest_ws_client = WebSocketPeer.new()
	
	var error = quest_ws_client.connect_to_url(Config.WS_QUEST_UPDATES)
	if error != OK:
		print("[ERROR] 连接任务更新WebSocket失败: ", error)
		quest_ws_connected = false
		quest_ws_reconnect_timer = QUEST_WS_RECONNECT_INTERVAL
	else:
		print("[INFO] 正在连接任务更新WebSocket: ", Config.WS_QUEST_UPDATES)

func _process(delta: float):
	"""处理WebSocket消息和重连"""
	if quest_ws_client == null:
		return
	
	# 检查连接状态
	quest_ws_client.poll()
	var state = quest_ws_client.get_ready_state()
	
	match state:
		WebSocketPeer.STATE_OPEN:
			if not quest_ws_connected:
				quest_ws_connected = true
				quest_ws_reconnect_timer = 0.0
				print("[INFO] ✅ 任务更新WebSocket已连接")
			
			# 接收消息
			var packet_count = quest_ws_client.get_available_packet_count()
			if packet_count > 0:
				print("[DEBUG] 📦 WebSocket收到 ", packet_count, " 个待处理消息")
			while quest_ws_client.get_available_packet_count() > 0:
				var packet = quest_ws_client.get_packet()
				var message = packet.get_string_from_utf8()
				print("[DEBUG] 📦 处理WebSocket消息: ", message)
				_handle_quest_update_message(message)
		
		WebSocketPeer.STATE_CLOSED:
			if quest_ws_connected:
				quest_ws_connected = false
				print("[WARN] 任务更新WebSocket连接已断开")
			
			# 尝试重连
			quest_ws_reconnect_timer += delta
			if quest_ws_reconnect_timer >= QUEST_WS_RECONNECT_INTERVAL:
				print("[INFO] 尝试重连任务更新WebSocket...")
				quest_ws_reconnect_timer = 0.0
				_connect_quest_websocket()
		
		WebSocketPeer.STATE_CONNECTING:
			# 连接中，等待
			pass
		
		WebSocketPeer.STATE_CLOSING:
			# 关闭中
			pass

func _handle_quest_update_message(message: String):
	"""处理任务更新消息"""
	var json = JSON.new()
	var parse_result = json.parse(message)
	
	if parse_result != OK:
		print("[ERROR] 解析任务更新消息失败: ", message)
		return
	
	var data = json.data
	if not data is Dictionary:
		print("[ERROR] 任务更新消息格式错误")
		return
	
	var msg_type = data.get("type", "")
	if msg_type == "quest_keyword_matched":
		var npc_name = data.get("npc_name", "")
		var quest_id = data.get("quest_id", "")
		var matched_keyword = data.get("matched_keyword", "")
		
		print("[INFO] 📡 收到任务更新: quest_id=", quest_id, ", keyword=", matched_keyword)
		quest_update_received.emit(npc_name, quest_id, matched_keyword)
	elif msg_type == "external_dialogue_ws_status":
		# ⭐ 处理外部对话WebSocket连接状态
		var status = data.get("status", "")
		var status_message = data.get("message", "")
		print("[INFO] 📡 外部对话WebSocket状态: ", status, " - ", status_message)
		
		# 发送信号
		external_dialogue_ws_status_received.emit(status, status_message)
		
		# ⭐ 根据 WebSocket 连接状态控制玩家交互状态
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("set_interacting"):
			if status == "connected":
				# 外部对话WebSocket已连接，禁用玩家移动
				player.set_interacting(true)
				print("[INFO] ✅ 外部对话系统已连接，玩家移动已禁用")
			elif status == "disconnected":
				# 外部对话WebSocket已断开，恢复玩家移动
				player.set_interacting(false)
				print("[INFO] ⚠️ 外部对话系统已断开，玩家移动已恢复")
		
		# ⭐ TODO: 其他处理外部对话WebSocket连接状态变化的逻辑
		# 可以在这里：
		# 1. 更新UI显示连接状态（如显示连接指示器）
		# 2. 启用/禁用相关功能
		# 3. 显示提示信息给用户
		# 4. 记录连接状态日志
	elif message == "pong":
		# 心跳响应，忽略
		pass
	else:
		print("[WARN] 未知的任务更新消息类型: ", msg_type)
