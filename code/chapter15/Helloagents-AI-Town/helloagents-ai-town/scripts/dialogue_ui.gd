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
const NETVIDEO_CLIENT_PATH = "/Users/tal/Souces/webrtc/rtcengine-mac-release/src/bin/macx/NetVideoClient.app"

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

	if event is InputEventKey and event.pressed and not event.echo:
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

		# 屏蔽移动键和交互键,防止触发游戏操作 ⭐ WASD键
		if event.keycode in [KEY_E, KEY_SPACE, KEY_W, KEY_A, KEY_S, KEY_D]:
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

func start_dialogue(npc_name: String):
	"""开始与NPC对话"""
	current_npc_name = npc_name

	# ⭐ 如果与青年李白对话，启动外部程序
	if npc_name == "青年李白":
		start_external_app_for_lisi()

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
	if message.contains("任务"):
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

func _on_chat_response_received(npc_name: String, message: String):
	"""收到NPC回复"""
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
	
	# ⭐ 检查对话任务进度
	_check_dialogue_quests(npc_name, message)
	
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
func start_external_app_for_lisi():
	"""为青年李白启动外部程序（跨平台支持）"""
	print("[INFO] 检测到与青年李白对话，准备启动NetVideoClient")
	
	# 使用外部程序管理器（推荐方式，已支持跨平台）
	if external_app_manager and external_app_manager.has_method("start_netvideo_client_simple"):
		var success = external_app_manager.start_netvideo_client_simple()
		if success:
			dialogue_text.append_text("[color=green]📹 视频通话客户端已启动...[/color]\n")
			print("[INFO] ✅ NetVideoClient已启动")
		else:
			dialogue_text.append_text("[color=red]❌ 视频通话客户端启动失败[/color]\n")
			print("[ERROR] ❌ NetVideoClient启动失败")
	else:
		# 备用方案：直接调用（跨平台）
		var os_name = OS.get_name()
		var path = NETVIDEO_CLIENT_PATH  # 使用旧的常量作为备用
		var output = []
		var exit_code = -1
		
		if os_name == "macOS" or os_name == "OSX":
			# macOS: 使用open命令
			var open_args = PackedStringArray([path])
			exit_code = OS.execute("open", open_args, output)
		elif os_name == "Windows":
			# Windows: 使用start命令
			var start_args = PackedStringArray(["/B", path])
			exit_code = OS.execute("cmd.exe", PackedStringArray(["/C", "start"] + start_args), output)
		else:
			print("[ERROR] 不支持的操作系统: ", os_name)
			dialogue_text.append_text("[color=red]❌ 不支持的操作系统[/color]\n")
			return
		
		if exit_code == 0:
			dialogue_text.append_text("[color=green]📹 视频通话客户端已启动...[/color]\n")
			print("[INFO] ✅ NetVideoClient已启动（备用方式）")
		else:
			dialogue_text.append_text("[color=red]❌ 视频通话客户端启动失败[/color]\n")
			print("[ERROR] ❌ NetVideoClient启动失败，退出代码: ", exit_code)

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

# ⭐ 任务系统集成：检查对话任务进度
func _check_dialogue_quests(npc_name: String, message: String):
	"""检查对话任务进度"""
	if not has_node("/root/QuestManager"):
		return
	
	var active_quests = QuestManager.get_active_quests()
	
	for quest_id in active_quests:
		var quest_data = QuestManager.get_active_quest_data(quest_id)
		var quest = quest_data.get("quest", {})
		
		# 检查是否是对话任务
		if quest.get("type") == "dialogue" and quest.get("npc") == npc_name:
			# 检查关键词
			var keywords = quest.get("keywords", [])
			
			for keyword in keywords:
				if message.contains(keyword):
					# 更新任务进度（传入关键词）
					QuestManager.update_quest_progress(quest_id, -1, keyword, "")
					break

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
			
			# 收集所有关键词，更新进度
			for keyword in keywords:
				QuestManager.update_quest_progress(quest_id, -1, keyword, "")
			
			# 确保进度达到完成要求
			var current_progress = quest_data.get("progress", 0)
			if current_progress < required_keywords:
				# 如果进度还不够，直接设置进度
				QuestManager.update_quest_progress(quest_id, required_keywords, "", "")
			
			# 然后完成任务（complete_quest会检查进度并完成）
			QuestManager.complete_quest(quest_id)
			completed_count += 1
			print("[TEST] 测试模式：完成任务 ", quest.get("title", quest_id))
	
	if completed_count > 0:
		print("[TEST] ✅ 共完成 ", completed_count, " 个对话任务")
	else:
		print("[TEST] ⚠️ 没有找到进行中的对话任务")
