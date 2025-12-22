# 外部程序管理器
extends Node

class_name ExternalAppManager

# NetVideoClient路径
const NETVIDEO_CLIENT_PATH = "/Users/tal/Souces/webrtc/rtcengine-mac-release/src/bin/macx/NetVideoClient"

# 单例
static var instance: ExternalAppManager = null

func _ready():
	instance = self
	print("[INFO] 外部程序管理器已初始化")

# 启动NetVideoClient（简单方式，推荐）
func start_netvideo_client_simple(args: PackedStringArray = []) -> bool:
	"""使用open命令启动NetVideoClient.app（macOS标准方式）"""
	print("[INFO] 准备启动NetVideoClient: ", NETVIDEO_CLIENT_PATH)
	
	# 检查.app文件是否存在
	if not DirAccess.dir_exists_absolute(NETVIDEO_CLIENT_PATH):
		print("[ERROR] NetVideoClient.app不存在: ", NETVIDEO_CLIENT_PATH)
		return false
	
	# 在macOS上，使用open命令启动.app文件
	# open命令会立即返回，不会阻塞
	var output = []
	var open_args = PackedStringArray([NETVIDEO_CLIENT_PATH])
	
	# 如果有额外参数，添加到open命令后
	if args.size() > 0:
		open_args.append("--args")
		for arg in args:
			open_args.append(arg)
	
	var exit_code = OS.execute("open", open_args, output)
	
	if exit_code == 0:
		print("[INFO] ✅ NetVideoClient已启动")
		return true
	else:
		print("[ERROR] ❌ NetVideoClient启动失败，退出代码: ", exit_code)
		return false

# 启动NetVideoClient（带参数版本）
func start_netvideo_client(args: PackedStringArray = []) -> bool:
	"""启动NetVideoClient（与simple版本相同，保持兼容性）"""
	return start_netvideo_client_simple(args)

# 检查程序是否运行
func is_netvideo_running() -> bool:
	"""检查NetVideoClient是否正在运行"""
	# 使用pgrep命令检查（macOS）
	var output = []
	var pgrep_args = PackedStringArray(["-f", "NetVideoClient"])
	var exit_code = OS.execute("pgrep", pgrep_args, output, true)
	
	if exit_code == 0 and output.size() > 0:
		var result = output[0].strip_edges()
		return result != ""
	
	return false

# 停止程序
func stop_netvideo_client():
	"""停止NetVideoClient"""
	# 使用killall命令
	var output = []
	var killall_args = PackedStringArray(["NetVideoClient"])
	OS.execute("killall", killall_args, output)
	print("[INFO] 尝试停止NetVideoClient（killall方式）")

# 获取单例
static func get_instance() -> ExternalAppManager:
	return instance
