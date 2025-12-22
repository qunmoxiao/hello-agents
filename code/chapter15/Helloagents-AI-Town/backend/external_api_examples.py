"""外部接口使用示例 - 展示如何注册和使用外部接口钩子"""

from external_api_manager import get_external_api_manager
from datetime import datetime
import asyncio

# 获取外部接口管理器
api_manager = get_external_api_manager()

# ==================== 示例1: 对话日志记录 ====================

async def log_dialogue_to_external(
    npc_name: str, 
    player_id: str, 
    player_message: str, 
    npc_response: str, 
    **kwargs
):
    """将对话记录到外部系统"""
    data = {
        "npc_name": npc_name,
        "player_id": player_id,
        "player_message": player_message,
        "npc_response": npc_response,
        "timestamp": datetime.now().isoformat()
    }
    
    # 调用外部API
    result = await api_manager.call_external_api(
        url="/api/dialogues",  # 相对于base_url的路径
        method="POST",
        data=data
    )
    
    if result:
        print(f"✅ 对话已记录到外部系统: {npc_name}")

# 注册钩子（取消注释以启用）
# api_manager.register_hook('after_chat', log_dialogue_to_external)

# ==================== 示例2: 好感度变化通知 ====================

async def notify_affinity_change(
    npc_name: str, 
    player_id: str, 
    old_affinity: float, 
    new_affinity: float, 
    change_amount: float = 0,
    **kwargs
):
    """好感度变化时发送通知（只在变化超过阈值时通知）"""
    # 只在好感度变化超过5时通知
    if abs(change_amount) >= 5:
        data = {
            "npc_name": npc_name,
            "player_id": player_id,
            "old_affinity": old_affinity,
            "new_affinity": new_affinity,
            "change_amount": change_amount,
            "timestamp": datetime.now().isoformat()
        }
        
        result = await api_manager.call_external_api(
            url="/api/notifications/affinity",
            method="POST",
            data=data
        )
        
        if result:
            print(f"✅ 好感度变化通知已发送: {npc_name} ({old_affinity:.1f} -> {new_affinity:.1f})")

# 注册钩子（取消注释以启用）
# api_manager.register_hook('on_affinity_change', notify_affinity_change)

# ==================== 示例3: 关键词触发任务 ====================

async def trigger_task_on_keyword(
    npc_name: str, 
    player_id: str, 
    message: str, 
    **kwargs
):
    """检测关键词并触发任务"""
    # 定义关键词和对应的任务类型
    keyword_tasks = {
        "任务": "task_accept",
        "接受": "task_accept",
        "完成": "task_complete",
        "提交": "task_submit",
        "领取": "task_receive"
    }
    
    for keyword, task_type in keyword_tasks.items():
        if keyword in message:
            data = {
                "npc_name": npc_name,
                "player_id": player_id,
                "message": message,
                "task_type": task_type,
                "keyword": keyword,
                "timestamp": datetime.now().isoformat()
            }
            
            result = await api_manager.call_external_api(
                url="/api/tasks/trigger",
                method="POST",
                data=data
            )
            
            if result:
                print(f"✅ 任务已触发: {task_type} (关键词: {keyword})")
            break

# 注册钩子（取消注释以启用）
# api_manager.register_hook('before_chat', trigger_task_on_keyword)

# ==================== 示例4: 游戏事件触发 ====================

async def trigger_game_event(
    npc_name: str, 
    player_id: str, 
    player_message: str, 
    npc_response: str, 
    **kwargs
):
    """根据对话内容触发游戏事件"""
    # 检测特殊对话内容
    special_events = {
        "你好": "greeting",
        "再见": "farewell",
        "谢谢": "thanks",
        "帮助": "help_request"
    }
    
    for keyword, event_type in special_events.items():
        if keyword in player_message:
            data = {
                "event_type": event_type,
                "npc_name": npc_name,
                "player_id": player_id,
                "message": player_message,
                "timestamp": datetime.now().isoformat()
            }
            
            result = await api_manager.call_external_api(
                url="/api/events",
                method="POST",
                data=data
            )
            
            if result:
                print(f"✅ 游戏事件已触发: {event_type} (NPC: {npc_name})")
            break

# 注册钩子（取消注释以启用）
# api_manager.register_hook('after_chat', trigger_game_event)

# ==================== 示例5: 统计对话次数 ====================

dialogue_count = {}  # 简单的内存统计（生产环境应使用数据库）

async def count_dialogues(
    npc_name: str, 
    player_id: str, 
    **kwargs
):
    """统计对话次数"""
    key = f"{player_id}:{npc_name}"
    dialogue_count[key] = dialogue_count.get(key, 0) + 1
    
    # 每10次对话发送一次统计
    if dialogue_count[key] % 10 == 0:
        data = {
            "player_id": player_id,
            "npc_name": npc_name,
            "count": dialogue_count[key],
            "timestamp": datetime.now().isoformat()
        }
        
        result = await api_manager.call_external_api(
            url="/api/statistics/dialogues",
            method="POST",
            data=data
        )
        
        if result:
            print(f"✅ 对话统计已发送: {npc_name} ({dialogue_count[key]}次)")

# 注册钩子（取消注释以启用）
# api_manager.register_hook('after_chat', count_dialogues)

# ==================== 示例6: 自定义外部接口调用 ====================

async def custom_external_call(
    npc_name: str,
    player_id: str,
    player_message: str,
    npc_response: str,
    **kwargs
):
    """自定义外部接口调用示例"""
    # 构建你的自定义数据
    custom_data = {
        "npc_name": npc_name,
        "player_id": player_id,
        "player_message": player_message,
        "npc_response": npc_response,
        "custom_field": "custom_value",
        "timestamp": datetime.now().isoformat()
    }
    
    # 调用你的外部接口
    result = await api_manager.call_external_api(
        url="https://your-custom-api.com/endpoint",  # 完整URL
        method="POST",
        data=custom_data,
        headers={
            "Authorization": "Bearer your-token-here",  # 如果需要认证
            "X-Custom-Header": "custom-value"
        }
    )
    
    if result:
        print(f"✅ 自定义接口调用成功: {npc_name}")
        # 处理返回结果
        # if result.get("status") == "success":
        #     do_something()

# 注册钩子（取消注释以启用）
# api_manager.register_hook('after_chat', custom_external_call)

# ==================== 使用说明 ====================

"""
使用步骤：

1. 取消注释你想要使用的钩子注册代码
2. 修改URL和数据结构以适应你的外部接口
3. 在 main.py 的 lifespan 函数中导入此模块：
   
   from external_api_examples import *  # 导入所有示例

4. 或者只导入你需要的钩子：
   
   from external_api_examples import log_dialogue_to_external
   api_manager.register_hook('after_chat', log_dialogue_to_external)

5. 配置环境变量（.env文件）：
   EXTERNAL_API_ENABLED=true
   EXTERNAL_API_TIMEOUT=5.0
   EXTERNAL_API_BASE_URL=https://your-api.com

注意事项：
- 所有钩子函数都是异步执行的，不会阻塞主流程
- 外部接口调用失败不会影响对话流程
- 建议设置合理的超时时间（3-5秒）
- 生产环境建议使用数据库而不是内存存储统计信息
"""

