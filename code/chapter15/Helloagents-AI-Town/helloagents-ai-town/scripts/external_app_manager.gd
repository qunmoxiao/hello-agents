# 外部程序管理器
extends Node

class_name ExternalAppManager

# NetVideoClient路径配置（根据平台自动选择）
# macOS路径
const NETVIDEO_CLIENT_PATH_MAC = ""
# Windows路径（请根据实际路径修改）
const NETVIDEO_CLIENT_PATH_WIN = ""

# 单例
static var instance: ExternalAppManager = null

func _ready():
	instance = self
	print("[INFO] 外部程序管理器已初始化")
	print("[INFO] 当前操作系统: ", OS.get_name())

# 获取当前平台的程序路径
func get_netvideo_client_path() -> String:
	"""根据当前操作系统返回对应的程序路径"""
	var os_name = OS.get_name()
	print("[DEBUG] 检测到的操作系统名称: ", os_name)
	if os_name == "macOS" or os_name == "OSX":
		return NETVIDEO_CLIENT_PATH_MAC
	elif os_name == "Windows" or os_name.begins_with("Windows"):
		return NETVIDEO_CLIENT_PATH_WIN
	else:
		print("[WARNING] 未识别的操作系统: ", os_name)
		return NETVIDEO_CLIENT_PATH_MAC  # 默认返回macOS路径

# 检查程序文件是否存在
func check_netvideo_client_exists() -> bool:
	"""检查NetVideoClient程序是否存在"""
	var path = get_netvideo_client_path()
	var os_name = OS.get_name()
	
	if os_name == "macOS" or os_name == "OSX":
		# macOS: .app是一个目录
		return DirAccess.dir_exists_absolute(path)
	elif os_name == "Windows":
		# Windows: .exe是一个文件
		return FileAccess.file_exists(path)
	else:
		return false

# 启动NetVideoClient（跨平台版本）
func start_netvideo_client_simple(args: PackedStringArray = []) -> bool:
	"""跨平台启动NetVideoClient"""
	var path = get_netvideo_client_path()
	var os_name = OS.get_name()
	
	print("[INFO] 准备启动NetVideoClient: ", path)
	print("[INFO] 操作系统: ", os_name)
	
	# 检查程序是否存在
	if not check_netvideo_client_exists():
		print("[ERROR] NetVideoClient不存在: ", path)
		return false
	
	var output = []
	var exit_code = 0
	
	if os_name == "macOS" or os_name == "OSX":
		# macOS: 使用open命令启动.app文件
		var open_args = PackedStringArray([path])
		# 如果有额外参数，添加到open命令后
		if args.size() > 0:
			open_args.append("--args")
			for arg in args:
				open_args.append(arg)
		exit_code = OS.execute("open", open_args, output)
		
	elif os_name == "Windows" or os_name.begins_with("Windows"):
		# Windows: 直接执行exe文件
		print("[DEBUG] Windows启动路径: ", path)
		var file_exists = FileAccess.file_exists(path)
		print("[DEBUG] 文件是否存在: ", file_exists)
		
		if not file_exists:
			print("[ERROR] 文件不存在，无法启动: ", path)
			return false
		
		# 方式1: 尝试使用OS.create_process（Godot 4.x推荐方式）
		print("[DEBUG] 尝试使用OS.create_process启动")
		var all_args = args.duplicate()
		var pid = OS.create_process(path, all_args, false)
		print("[DEBUG] create_process返回PID: ", pid)
		if pid > 0:
			print("[INFO] ✅ 使用create_process成功启动，PID: ", pid)
			return true
		else:
			print("[WARN] create_process失败 (PID=", pid, ")，尝试备用方式")
		
		# 方式2: 直接使用OS.execute执行exe（简单方式）
		print("[DEBUG] 尝试直接执行exe文件")
		var exe_args = args.duplicate()
		exit_code = OS.execute(path, exe_args, output, false, false)
		print("[DEBUG] 直接执行退出代码: ", exit_code)
		if exit_code == 0:
			print("[INFO] ✅ 直接执行成功")
			return true
		
		# 方式3: 使用start命令（备用方式，不阻塞，立即返回）
		# start命令语法: start "" /B "程序路径" [参数...]
		print("[DEBUG] 尝试使用start命令启动")
		# 构建start命令：start "" /B "路径" [参数...]
		var start_cmd_parts = PackedStringArray()
		start_cmd_parts.append("")  # 空标题
		start_cmd_parts.append("/B")  # /B 表示不创建新窗口
		start_cmd_parts.append(path)  # 路径（OS.execute会自动处理空格）
		# 添加额外参数
		for arg in args:
			start_cmd_parts.append(arg)
		
		# 构建cmd.exe的参数：cmd.exe /C start "" /B "路径" [参数...]
		var cmd_args = PackedStringArray()
		cmd_args.append("/C")
		cmd_args.append("start")
		cmd_args.append_array(start_cmd_parts)
		
		print("[DEBUG] 执行命令: cmd.exe ", cmd_args)
		exit_code = OS.execute("cmd.exe", cmd_args, output, true, false)
		print("[DEBUG] start命令退出代码: ", exit_code)
		
		# 打印输出信息用于调试
		if output.size() > 0:
			print("[DEBUG] 命令输出: ", output)
	else:
		print("[ERROR] 不支持的操作系统: ", os_name)
		return false
	
	if exit_code == 0:
		print("[INFO] ✅ NetVideoClient已启动")
		return true
	else:
		print("[ERROR] ❌ NetVideoClient启动失败，退出代码: ", exit_code)
		if output.size() > 0:
			print("[ERROR] 错误输出: ", output)
		return false

# 启动NetVideoClient（带参数版本）
func start_netvideo_client(args: PackedStringArray = []) -> bool:
	"""启动NetVideoClient（与simple版本相同，保持兼容性）"""
	return start_netvideo_client_simple(args)

# 检查程序是否运行（跨平台）
func is_netvideo_running() -> bool:
	"""检查NetVideoClient是否正在运行"""
	var os_name = OS.get_name()
	var output = []
	var exit_code = 0
	
	if os_name == "macOS" or os_name == "OSX":
		# macOS: 使用pgrep命令检查
		var pgrep_args = PackedStringArray(["-f", "NetVideoClient"])
		exit_code = OS.execute("pgrep", pgrep_args, output, true)
		
		if exit_code == 0 and output.size() > 0:
			var result = output[0].strip_edges()
			return result != ""
			
	elif os_name == "Windows":
		# Windows: 使用tasklist命令检查
		var tasklist_args = PackedStringArray(["/FI", "IMAGENAME eq NetVideoClient.exe", "/FO", "CSV"])
		exit_code = OS.execute("tasklist", tasklist_args, output, true)
		
		if exit_code == 0 and output.size() > 0:
			# tasklist输出包含表头，如果进程存在，输出行数会大于1
			# 简单检查：如果输出包含进程名，说明正在运行
			for line in output:
				if "NetVideoClient.exe" in line:
					return true
	else:
		print("[WARNING] 未识别的操作系统，无法检查进程状态: ", os_name)
	
	return false

# 停止程序（跨平台）
func stop_netvideo_client():
	"""停止NetVideoClient"""
	var os_name = OS.get_name()
	var output = []
	
	if os_name == "macOS" or os_name == "OSX":
		# macOS: 使用killall命令
		var killall_args = PackedStringArray(["NetVideoClient"])
		OS.execute("killall", killall_args, output)
		print("[INFO] 尝试停止NetVideoClient（killall方式）")
		
	elif os_name == "Windows":
		# Windows: 使用taskkill命令
		var taskkill_args = PackedStringArray(["/F", "/IM", "NetVideoClient.exe"])
		OS.execute("taskkill", taskkill_args, output)
		print("[INFO] 尝试停止NetVideoClient（taskkill方式）")
	else:
		print("[WARNING] 未识别的操作系统，无法停止进程: ", os_name)

# 获取单例
static func get_instance() -> ExternalAppManager:
	return instance
