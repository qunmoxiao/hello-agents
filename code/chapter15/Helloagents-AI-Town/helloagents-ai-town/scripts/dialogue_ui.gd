# 对话UI脚本
extends CanvasLayer

# 节点引用
@onready var panel: Panel = $Panel
@onready var npc_name_label: Label = $Panel/NPCName
@onready var npc_title_label: Label = $Panel/NPCTitle
@onready var dialogue_text: RichTextLabel = $Panel/DialogueText
@onready var player_input: LineEdit = $Panel/PlayerInput
@onready var send_button: Button = $Panel/SendButton
@onready var close_button: Button = $Panel/CloseButton

# 当前对话的NPC
var current_npc_name: String = ""

# API客户端引用
var api_client: Node = null

# ⭐ 外部程序管理器引用
var external_app_manager: ExternalAppManager = null

# ⭐ NetVideoClient路径（备用）
const NETVIDEO_CLIENT_PATH_MAC = "/Users/tal/Souces/webrtc/rtcengine-mac-release/src/bin/macx/NetVideoClient.app"
const NETVIDEO_CLIENT_PATH_WIN = "E:\\code\\zhiyin\\zhiyinjiejiewinproject\\VirtualHuman\\VirtualHuman.exe"
func _ready():
	# 添加到对话系统组
	add_to_group("dialogue_system")

	# 初始隐藏
	visible = false

	# 连接按钮信号
	send_button.pressed.connect(_on_send_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	player_input.text_submitted.connect(_on_text_submitted)

	# 获取API客户端
	api_client = get_node_or_null("/root/APIClient")
	if api_client:
		api_client.chat_response_received.connect(_on_chat_response_received)
		api_client.chat_error.connect(_on_chat_error)

	# ⭐ 获取外部程序管理器
	external_app_manager = get_node_or_null("/root/ExternalAppManager")
	if not external_app_manager:
		external_app_manager = get_tree().get_first_node_in_group("external_app_manager")
	
	if external_app_manager:
		print("[INFO] 外部程序管理器已连接")
	else:
		print("[WARN] 外部程序管理器未找到，将使用直接调用方式")

	print("[INFO] 对话UI初始化完成")

# ⭐ 处理对话框快捷键
func _input(event: InputEvent):
	# 如果对话框不可见,不处理
	if not visible:
		return

	if event is InputEventKey and not event.echo:
		# ⭐ 处理按键按下事件
		if event.pressed:
			# ESC键 - 关闭对话框 
			if event.keycode == KEY_ESCAPE:
				hide_dialogue()
				get_viewport().set_input_as_handled()
				print("[DEBUG] ESC键关闭对话框")
				return

			# 回车键 - 发送消息 (仅当输入框有焦点时) 
			# 注意: LineEdit的text_submitted信号已经处理了回车,这里只是额外保险
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				# 如果输入框有焦点,让LineEdit自己处理
				if player_input.has_focus():
					return
				# 否则手动发送
				send_message()
				get_viewport().set_input_as_handled()
				print("[DEBUG] 回车键发送消息")
				return

			# 屏蔽移动键和交互键,防止触发游戏操作 ⭐ WASD键 + I键（防止误打开背包）
			if event.keycode in [KEY_E, KEY_SPACE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_I]:
				get_viewport().set_input_as_handled()
				# 只在第一次屏蔽时打印,避免刷屏
				match event.keycode:
					KEY_E:
						print("[DEBUG] 对话框中屏蔽了E键输入")
					KEY_SPACE:
						print("[DEBUG] 对话框中屏蔽了空格键输入")
					KEY_W:
						print("[DEBUG] 对话框中屏蔽了W键输入")
					KEY_A:
						print("[DEBUG] 对话框中屏蔽了A键输入")
					KEY_S:
						print("[DEBUG] 对话框中屏蔽了S键输入")
					KEY_D:
						print("[DEBUG] 对话框中屏蔽了D键输入")
					KEY_I:
						print("[DEBUG] 对话框中屏蔽了I键输入(防止误打开背包)")
		else:
			# ⭐ 处理按键释放事件 - 确保WASD键的释放事件也被屏蔽
			if event.keycode in [KEY_E, KEY_SPACE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_I]:
				get_viewport().set_input_as_handled()
				print("[DEBUG] 对话框中屏蔽了按键释放: ", event.keycode)

func start_dialogue(npc_name: String):
	"""开始与NPC对话"""
	current_npc_name = npc_name

	# ⭐ 如果与李白系列对话，启动外部程序
	var external_app_success = false
	if npc_name == "青年李白":
		external_app_success = start_external_app_for_lisi(1)
	elif npc_name == "中年李白":
		external_app_success = start_external_app_for_lisi(2)
	elif npc_name == "老年李白":
		external_app_success = start_external_app_for_lisi(3)

	# ⭐ 如果外部程序启动成功，不显示聊天框，直接返回
	# ⭐ 注意：不再在这里控制 player 的 interaction，改为通过外部对话 WebSocket 连接状态控制
	if external_app_success:
		print("[INFO] 外部程序已启动，不显示聊天框")
		# 通知NPC进入交互状态 (停止移动) 
		var npc = get_npc_by_name(npc_name)
		if npc and npc.has_method("set_interacting"):
			npc.set_interacting(true)
		# ⭐ 不再控制玩家交互状态，改为通过外部对话 WebSocket 连接状态控制
		return

	# ⭐ 外部程序启动失败，使用聊天框文字输入
	print("[INFO] 外部程序启动失败，使用聊天框文字输入")

	# 通知NPC进入交互状态 (停止移动) 
	var npc = get_npc_by_name(npc_name)
	if npc and npc.has_method("set_interacting"):
		npc.set_interacting(true)

	# 设置NPC信息
	npc_name_label.text = npc_name
	npc_title_label.text = Config.NPC_TITLES.get(npc_name, "")
	
	# 根据NPC设置对话框色彩风格
	_setup_dialogue_style(npc_name)
	
	# 等待一帧，确保布局已计算，然后更新按钮对齐
	await get_tree().process_frame
	_update_button_alignment()

	# 清空对话内容
	dialogue_text.clear()
	dialogue_text.append_text("[color=gray]与 " + npc_name + " 的对话开始...[/color]\n")

	# 清空输入框
	player_input.text = ""

	# 显示对话框
	show_dialogue()

	# 聚焦输入框
	player_input.grab_focus()

	print("[INFO] 开始对话: ", npc_name)

func show_dialogue():
	"""显示对话框"""
	visible = true

	# 通知玩家进入交互状态 (禁用移动)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_interacting"):
		player.set_interacting(true)

func hide_dialogue():
	"""隐藏对话框"""
	visible = false

	# ⭐ 释放输入框焦点，防止残留按键状态
	if player_input and player_input.has_focus():
		player_input.release_focus()
		print("[DEBUG] 已释放输入框焦点")

	# ⭐ 强制释放所有移动相关的输入动作，防止残留按键状态
	# 这可以确保即使按键状态被保留，也不会影响玩家移动
	Input.action_release("ui_up")
	Input.action_release("ui_down")
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	print("[DEBUG] 已强制释放所有移动输入动作")

	# 通知NPC退出交互状态 (恢复移动) 
	if current_npc_name != "":
		var npc = get_npc_by_name(current_npc_name)
		if npc and npc.has_method("set_interacting"):
			npc.set_interacting(false)

	current_npc_name = ""

	# ⭐ 通知玩家退出交互状态，并强制设置为原地等待
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("set_interacting"):
			player.set_interacting(false)
		# ⭐ 强制清除玩家速度，确保关闭对话框后不会继续移动
		if player.has_method("force_stop"):
			player.force_stop()
		elif "velocity" in player:
			player.velocity = Vector2.ZERO
		
		# ⭐ 延迟一帧再恢复移动，确保输入状态已清除（特别是WASD键）
		# 这样可以避免外部程序或输入焦点切换导致的残留按键状态
		await get_tree().process_frame
		if player and player.has_method("force_stop"):
			player.force_stop()
		print("[DEBUG] 对话框已关闭，输入状态已清除")

func _on_send_button_pressed():
	"""发送按钮点击"""
	send_message()

func _on_text_submitted(_text: String):
	"""输入框回车"""
	send_message()

func send_message():
	"""发送消息"""
	var message = player_input.text.strip_edges()
	
	if message.is_empty():
		return
	
	if current_npc_name.is_empty():
		print("[ERROR] 没有选择NPC")
		return
	
	# ⭐ 测试功能：如果玩家输入"完成任务"，直接完成当前对话任务
	if message.contains("6789"):
		_complete_dialogue_quests_test(current_npc_name)
		# 显示提示信息
		dialogue_text.append_text("\n[color=cyan]玩家:[/color] " + message + "\n")
		dialogue_text.append_text("[color=green]✨ 测试模式：任务已完成！[/color]\n")
		player_input.text = ""
		return
	
	# 显示玩家消息
	dialogue_text.append_text("\n[color=cyan]玩家:[/color] " + message + "\n")
	
	# 清空输入框
	player_input.text = ""
	
	# 显示等待提示
	dialogue_text.append_text("[color=gray]等待回复...[/color]\n")
	
	# 发送API请求
	if api_client:
		api_client.send_chat(current_npc_name, message)
	else:
		print("[ERROR] API客户端未找到")

func _on_chat_response_received(npc_name: String, message: String, matched_keywords: Array = []):
	"""收到NPC回复
	Args:
		npc_name: NPC名称
		message: NPC回复消息
		matched_keywords: 后端语义匹配返回的关键词列表（可选）
	"""
	if npc_name != current_npc_name:
		return
	
	# 移除"等待回复..."
	var text = dialogue_text.get_parsed_text()
	if text.ends_with("等待回复...\n"):
		# 清除最后一行
		dialogue_text.clear()
		var lines = text.split("\n")
		for i in range(lines.size() - 2):
			dialogue_text.append_text(lines[i] + "\n")
	
	# 显示NPC回复
	dialogue_text.append_text("[color=yellow]" + npc_name + ":[/color] " + message + "\n")
	
	# ⭐ 检查对话任务进度（传入后端匹配的关键词）
	_check_dialogue_quests(npc_name, message, matched_keywords)
	
	# 滚动到底部
	dialogue_text.scroll_to_line(dialogue_text.get_line_count() - 1)

func _on_chat_error(error_message: String):
	"""对话错误"""
	dialogue_text.append_text("[color=red]错误: " + error_message + "[/color]\n")

func _on_close_button_pressed():
	"""关闭按钮点击"""
	hide_dialogue()

# ⭐ 根据名字获取NPC节点
func get_npc_by_name(npc_name: String) -> Node:
	"""根据名字获取NPC节点"""
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if npc.npc_name == npc_name:
			return npc
	return null

# ⭐ 为青年李白启动外部程序
func start_external_app_for_lisi(param: int) -> bool:
	"""为青年李白启动外部程序（跨平台支持）
	param: 整型参数，传递给外部程序
	Returns: bool - 如果外部程序启动成功返回true，否则返回false
	"""
	print("[INFO] 检测到与青年李白对话，准备启动NetVideoClient，参数: ", param)
	
	# 使用外部程序管理器（推荐方式，已支持跨平台）
	if external_app_manager and external_app_manager.has_method("start_netvideo_client_simple"):
		var args = PackedStringArray([str(param)])
		var success = external_app_manager.start_netvideo_client_simple(args)
		if success:
			print("[INFO] ✅ NetVideoClient已启动")
			return true
		else:
			print("[ERROR] ❌ NetVideoClient启动失败")
			return false
	else:
		# 备用方案：直接调用（跨平台）
		var os_name = OS.get_name()
		print("[WARN] 外部程序管理器不可用，使用备用方案")
		print("[DEBUG] 操作系统: ", os_name)
		
		# 根据操作系统选择路径
		var path = ""
		if os_name == "macOS" or os_name == "OSX":
			path = NETVIDEO_CLIENT_PATH_MAC
		elif os_name == "Windows" or os_name.begins_with("Windows"):
			path = NETVIDEO_CLIENT_PATH_WIN
		else:
			print("[ERROR] 不支持的操作系统: ", os_name)
			return false
		
		print("[DEBUG] 备用方案路径: ", path)
		var file_exists = false
		if os_name == "macOS" or os_name == "OSX":
			file_exists = DirAccess.dir_exists_absolute(path)
		elif os_name == "Windows" or os_name.begins_with("Windows"):
			file_exists = FileAccess.file_exists(path)
		
		print("[DEBUG] 文件是否存在: ", file_exists)
		if not file_exists:
			print("[ERROR] 文件不存在: ", path)
			return false
		
		var output = []
		var exit_code = -1
		
		if os_name == "macOS" or os_name == "OSX":
			# macOS: 使用open命令
			var open_args = PackedStringArray([path])
			exit_code = OS.execute("open", open_args, output)
		elif os_name == "Windows" or os_name.begins_with("Windows"):
			# Windows: 使用cmd先进入目录，然后启动程序，cmd窗口最小化
			var exe_dir = path.get_base_dir()
			var exe_name = path.get_file()
			# 构建命令：cd进入目录，然后启动程序
			var cmd_command = "cd /d \"" + exe_dir + "\" && \"" + exe_name + "\" " + str(param)
			# 使用 start /MIN 启动最小化的cmd窗口
			var cmd_args = PackedStringArray(["/C", "start", "/MIN", "cmd.exe", "/K", cmd_command])
			print("[INFO] 执行目录: ", exe_dir)
			print("[INFO] 执行程序: ", exe_name)
			print("[INFO] cmd命令: ", cmd_command)
			print("[INFO] 执行参数: ", str(param))
			var pid = OS.create_process("cmd.exe", cmd_args, false)
			if pid > 0:
				exit_code = 0
				print("[INFO] cmd.exe已启动，------------进程ID: ", pid)
			else:
				exit_code = -1
				print("[ERROR] cmd.exe启动失败")
			return exit_code == 0
		
		if exit_code == 0:
			print("[INFO] ✅ NetVideoClient已启动（备用方式）")
			return true
		else:
			print("[ERROR] ❌ NetVideoClient启动失败，退出代码: ", exit_code)
			if output.size() > 0:
				print("[ERROR] 错误输出: ", output)
			return false

func _setup_dialogue_style(npc_name: String):
	"""根据NPC设置对话框色彩风格"""
	var style_box = StyleBoxFlat.new()
	var name_color = Color.WHITE
	var title_color = Color(0.7, 0.7, 0.7, 1.0)
	var panel_color = Color(0.1, 0.1, 0.15, 0.95)
	var border_color = Color(0.3, 0.3, 0.4, 1.0)
	
	match npc_name:
		"青年李白":
			# 青年时期：清新明亮，绿色、白色、青色
			name_color = Color(0.2, 0.7, 0.3, 1.0)  # 绿色
			title_color = Color(0.3, 0.6, 0.4, 1.0)  # 浅绿色
			panel_color = Color(0.9, 0.95, 0.9, 0.95)  # 浅绿色背景
			border_color = Color(0.2, 0.6, 0.3, 1.0)  # 深绿色边框
		"中年李白":
			# 中年时期：繁华华丽，红色、黄色、金色
			name_color = Color(0.9, 0.6, 0.2, 1.0)  # 金色/黄色
			title_color = Color(0.8, 0.5, 0.2, 1.0)  # 浅金色
			panel_color = Color(0.95, 0.9, 0.85, 0.95)  # 浅金色背景
			border_color = Color(0.8, 0.5, 0.2, 1.0)  # 金色边框
		"老年李白":
			# 老年时期：荒凉萧瑟，灰色、棕色、青色
			name_color = Color(0.6, 0.5, 0.4, 1.0)  # 棕色
			title_color = Color(0.5, 0.45, 0.4, 1.0)  # 浅棕色
			panel_color = Color(0.85, 0.8, 0.75, 0.95)  # 浅棕色/灰色背景
			border_color = Color(0.5, 0.45, 0.4, 1.0)  # 棕色边框
		_:
			# 默认样式
			name_color = Color.WHITE
			title_color = Color(0.7, 0.7, 0.7, 1.0)
			panel_color = Color(0.1, 0.1, 0.15, 0.95)
			border_color = Color(0.3, 0.3, 0.4, 1.0)
	
	# 设置Panel样式
	style_box.bg_color = panel_color
	style_box.border_color = border_color
	style_box.border_width_left = 4
	style_box.border_width_top = 4
	style_box.border_width_right = 4
	style_box.border_width_bottom = 4
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 0
	style_box.corner_radius_bottom_right = 0
	panel.add_theme_stylebox_override("panel", style_box)
	
	# 设置NPC名字颜色
	npc_name_label.add_theme_color_override("font_color", name_color)
	
	# 设置NPC标题颜色
	npc_title_label.add_theme_color_override("font_color", title_color)
	
	# 设置对话内容框背景样式（与Panel区分）
	var dialogue_bg_style = StyleBoxFlat.new()
	var dialogue_bg_color = Color(1.0, 1.0, 1.0, 0.3)  # 默认半透明白色
	
	match npc_name:
		"青年李白":
			# 青年时期：更浅的绿色背景
			dialogue_bg_color = Color(0.95, 1.0, 0.95, 0.4)  # 非常浅的绿色
		"中年李白":
			# 中年时期：更浅的金色背景
			dialogue_bg_color = Color(1.0, 0.98, 0.95, 0.4)  # 非常浅的金色
		"老年李白":
			# 老年时期：更浅的棕色背景
			dialogue_bg_color = Color(0.95, 0.92, 0.9, 0.4)  # 非常浅的棕色
		_:
			# 默认：半透明白色
			dialogue_bg_color = Color(1.0, 1.0, 1.0, 0.3)
	
	dialogue_bg_style.bg_color = dialogue_bg_color
	dialogue_bg_style.border_color = Color(0.5, 0.5, 0.5, 0.3)
	dialogue_bg_style.border_width_left = 2
	dialogue_bg_style.border_width_top = 2
	dialogue_bg_style.border_width_right = 2
	dialogue_bg_style.border_width_bottom = 2
	dialogue_bg_style.corner_radius_top_left = 8
	dialogue_bg_style.corner_radius_top_right = 8
	dialogue_bg_style.corner_radius_bottom_left = 8
	dialogue_bg_style.corner_radius_bottom_right = 8
	dialogue_text.add_theme_stylebox_override("normal", dialogue_bg_style)
	
	# 根据对话内容框宽度调整按钮位置
	_update_button_alignment()
	
	print("[INFO] 已设置对话框风格: ", npc_name, " - 颜色主题: ", name_color)

func _update_button_alignment():
	"""根据对话内容框宽度调整按钮位置，使其对齐"""
	if not dialogue_text:
		return
	
	var dialogue_width = dialogue_text.size.x
	if dialogue_width <= 0:
		# 如果宽度还没计算，使用offset计算
		dialogue_width = dialogue_text.offset_right - dialogue_text.offset_left
	
	# 按钮宽度和间距
	var button_width = 140.0
	var button_spacing = 10.0
	var input_margin_right = 10.0  # 输入框和按钮之间的间距
	
	# 计算按钮位置（右对齐）
	var input_right = dialogue_width - button_width * 2 - button_spacing - input_margin_right
	var send_left = input_right + input_margin_right
	var send_right = send_left + button_width
	var close_left = send_right + button_spacing
	var close_right = close_left + button_width
	
	# 更新输入框宽度
	if player_input:
		player_input.offset_right = input_right
	
	# 更新按钮位置
	if send_button:
		send_button.offset_left = send_left
		send_button.offset_right = send_right
	
	if close_button:
		close_button.offset_left = close_left
		close_button.offset_right = close_right
	
	print("[INFO] 按钮位置已对齐，对话内容框宽度: ", dialogue_width)

# ⭐ 任务系统集成：检查对话任务进度（支持同义词组匹配，支持多个关键字同时匹配）
func _check_dialogue_quests(npc_name: String, message: String, backend_matched_keywords: Array = []):
	"""检查对话任务进度
	Args:
		npc_name: NPC名称
		message: NPC回复消息
		backend_matched_keywords: 后端语义匹配返回的关键词列表（可选）
	"""
	if not has_node("/root/QuestManager"):
		return
	
	var active_quests = QuestManager.get_active_quests()
	
	for quest_id in active_quests:
		var quest_data = QuestManager.get_active_quest_data(quest_id)
		var quest = quest_data.get("quest", {})
		
		# 检查是否是对话任务
		if quest.get("type") == "dialogue" and quest.get("npc") == npc_name:
			# 检查关键词（支持同义词组）
			var keywords = quest.get("keywords", [])
			var matched_keywords: Array[String] = []  # ⭐ 改为数组，支持多个关键字匹配
			var frontend_matched_keywords: Array[String] = []  # 前端匹配的关键字
			
			# ⭐ 第一步：前端同义词匹配（遍历所有关键词组，收集所有匹配的关键字）
			for keyword_group in keywords:
				# 支持两种格式：字符串（向后兼容）或数组（同义词组）
				var keyword_list = []
				if keyword_group is Array:
					keyword_list = keyword_group
				else:
					# 向后兼容：单个字符串也当作数组处理
					keyword_list = [keyword_group]
				
				# 检查是否包含同义词组中的任意一个
				for keyword in keyword_list:
					if message.contains(keyword):
						var main_keyword = keyword_list[0]  # 使用第一个关键词作为主关键词
						# ⭐ 避免重复添加
						if main_keyword not in frontend_matched_keywords:
							frontend_matched_keywords.append(main_keyword)
							print("[INFO] 前端匹配到关键词（同义词）: ", main_keyword, " (同义词组: ", keyword_list, ")")
						break  # 找到匹配后跳出内层循环，继续检查下一个关键词组
			
			# ⭐ 第二步：如果前端没匹配到，检查后端语义匹配结果
			if frontend_matched_keywords.is_empty() and backend_matched_keywords.size() > 0:
				# 遍历关键词组，找到后端匹配的关键词对应的主关键词
				for keyword_group in keywords:
					var keyword_list = []
					if keyword_group is Array:
						keyword_list = keyword_group
					else:
						keyword_list = [keyword_group]
					
					# 检查后端匹配的关键词是否在这个同义词组中
					for backend_keyword in backend_matched_keywords:
						if backend_keyword in keyword_list:
							var main_keyword = keyword_list[0]  # 使用第一个关键词作为主关键词
							# ⭐ 避免重复添加
							if main_keyword not in matched_keywords:
								matched_keywords.append(main_keyword)
								print("[INFO] 后端语义匹配到关键词: ", main_keyword, " (后端返回: ", backend_keyword, ")")
							break  # 找到匹配后跳出内层循环，继续检查下一个关键词组
			else:
				# ⭐ 如果前端匹配到了，使用前端匹配的结果
				matched_keywords = frontend_matched_keywords
			
			# ⭐ 遍历所有匹配的关键字，逐个更新任务进度
			for matched_keyword in matched_keywords:
				QuestManager.update_quest_progress(quest_id, -1, matched_keyword, "")
				print("[INFO] ✅ 已更新任务进度: quest_id=", quest_id, ", keyword=", matched_keyword)

# ⭐ 测试功能：直接完成对话任务
func _complete_dialogue_quests_test(npc_name: String):
	"""测试功能：直接完成当前NPC的所有对话任务"""
	if not has_node("/root/QuestManager"):
		print("[WARN] QuestManager未找到")
		return
	
	var active_quests = QuestManager.get_active_quests()
	var completed_count = 0
	
	for quest_id in active_quests:
		var quest_data = QuestManager.get_active_quest_data(quest_id)
		var quest = quest_data.get("quest", {})
		
		# 检查是否是对话任务且匹配NPC
		if quest.get("type") == "dialogue" and quest.get("npc") == npc_name:
			# ⭐ 先更新进度到完成状态，让UI能看到进度变化
			var keywords = quest.get("keywords", [])
			var required_keywords = quest.get("required_keywords", keywords.size())
			
			# ⭐ 确保 keywords 是数组且元素都是字符串
			if not keywords is Array:
				print("[WARN] keywords 不是数组类型: ", keywords)
				continue
			
			# 收集所有关键词，更新进度
			for keyword in keywords:
				# ⭐ 确保 keyword 是字符串类型
				var keyword_str: String = ""
				if keyword is String:
					keyword_str = keyword
				else:
					# 如果不是字符串，尝试转换为字符串
					keyword_str = str(keyword)
					print("[WARN] 关键词不是字符串类型，已转换: ", keyword, " -> ", keyword_str)
				
				# ⭐ 只传递字符串类型的关键词
				if keyword_str != "":
					QuestManager.update_quest_progress(quest_id, -1, keyword_str, "")
			
			# 确保进度达到完成要求
			var current_progress = quest_data.get("progress", 0)
			if current_progress < required_keywords:
				# ⭐ 对于对话任务，不需要通过 progress 参数直接设置进度
				# 因为 update_quest_progress 会根据关键词自动计算进度
				# 如果进度还不够，说明关键词收集有问题，直接完成任务即可
				# complete_quest 函数会自动确保进度达到要求
				pass
			
			# 然后完成任务（complete_quest会检查进度并完成）
			QuestManager.complete_quest(quest_id)
			completed_count += 1
			print("[TEST] 测试模式：完成任务 ", quest.get("title", quest_id))
	
	if completed_count > 0:
		print("[TEST] ✅ 共完成 ", completed_count, " 个对话任务")
	else:
		print("[TEST] ⚠️ 没有找到进行中的对话任务")
