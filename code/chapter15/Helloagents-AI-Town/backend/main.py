"""赛博小镇 FastAPI 后端主程序"""

import json
import os
import asyncio
import uuid
from contextlib import asynccontextmanager
from typing import List, Dict, Any

import uvicorn
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from models import (
    ChatRequest,
    ChatResponse,
    NPCStatusResponse,
    NPCListResponse,
    NPCInfo,
    GeneratedQuizResponse,
)
from agents import get_npc_manager
from state_manager import get_state_manager
from quiz_generator import get_quiz_generator
from logger import (
    log_quiz_generation_start,
    log_quiz_generation_success,
    log_quiz_generation_failure,
    log_info,
    log_error,
)

# 生命周期管理
@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时
    print("\n" + "="*60)
    print("🎮 赛博小镇后端服务启动中...")
    print("="*60)
    
    # 验证配置
    settings.validate()
    
    # 初始化NPC管理器
    npc_manager = get_npc_manager()
    
    # 初始化并启动状态管理器
    state_manager = get_state_manager(settings.NPC_UPDATE_INTERVAL)
    await state_manager.start()
    
    print("\n✅ 所有服务已启动!")
    print(f"📡 API地址: http://{settings.API_HOST}:{settings.API_PORT}")
    print(f"📚 API文档: http://{settings.API_HOST}:{settings.API_PORT}/docs")
    print("="*60 + "\n")
    
    yield
    
    # 关闭时
    print("\n🛑 正在关闭服务...")
    await state_manager.stop()
    print("✅ 服务已关闭\n")

# 创建FastAPI应用
app = FastAPI(
    title=settings.API_TITLE,
    version=settings.API_VERSION,
    description="赛博小镇 - 基于HelloAgents的AI NPC对话系统",
    lifespan=lifespan
)

# CORS配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 获取全局实例
npc_manager = None
state_manager = None
quiz_generator = None

def get_managers():
    """获取管理器实例"""
    global npc_manager, state_manager, quiz_generator
    if npc_manager is None:
        npc_manager = get_npc_manager()
    if state_manager is None:
        state_manager = get_state_manager()
    if quiz_generator is None:
        quiz_generator = get_quiz_generator()
    return npc_manager, state_manager, quiz_generator

# ==================== 任务更新WebSocket连接管理器 ====================

class QuestUpdateManager:
    """管理前端WebSocket连接，用于广播任务更新"""
    
    def __init__(self):
        self.connections: Dict[str, WebSocket] = {}
        self.lock = asyncio.Lock()
    
    async def add_connection(self, connection_id: str, websocket: WebSocket):
        """添加连接"""
        async with self.lock:
            self.connections[connection_id] = websocket
            log_info(f"📡 任务更新连接已添加: {connection_id} (当前连接数: {len(self.connections)})")
    
    async def remove_connection(self, connection_id: str):
        """移除连接"""
        async with self.lock:
            if connection_id in self.connections:
                del self.connections[connection_id]
                log_info(f"📡 任务更新连接已移除: {connection_id} (当前连接数: {len(self.connections)})")
    
    async def broadcast_update(self, message: Dict[str, Any]):
        """广播任务更新消息给所有连接的前端"""
        if not self.connections:
            return
        
        message_json = json.dumps(message, ensure_ascii=False)
        disconnected = []
        
        async with self.lock:
            connections_copy = dict(self.connections)
        
        for connection_id, websocket in connections_copy.items():
            try:
                await websocket.send_text(message_json)
            except Exception as e:
                log_error(f"📡 广播消息失败 (连接 {connection_id}): {e}")
                disconnected.append(connection_id)
        
        # 清理断开的连接
        for conn_id in disconnected:
            await self.remove_connection(conn_id)

# 全局任务更新管理器
quest_update_manager = QuestUpdateManager()

# ⭐ 外部对话WebSocket连接状态跟踪
external_dialogue_ws_connected: bool = False
external_dialogue_ws_lock = asyncio.Lock()

# ==================== API路由 ====================

@app.get("/")
async def root():
    """根路径 - API信息"""
    return {
        "service": settings.API_TITLE,
        "version": settings.API_VERSION,
        "status": "running",
        "features": ["AI对话", "NPC记忆系统", "好感度系统", "批量状态更新"],
        "endpoints": {
            "docs": "/docs",
            "chat": "/chat",
            "npcs": "/npcs",
            "npcs_status": "/npcs/status",
            "npc_memories": "/npcs/{npc_name}/memories",
            "npc_affinity": "/npcs/{npc_name}/affinity",
            "all_affinities": "/affinities"
        }
    }

def _load_quests_data() -> Dict[str, Any]:
    """加载任务数据（内部函数，避免重复读取文件）"""
    try:
        quests_path = os.path.join(os.path.dirname(__file__), "..", "helloagents-ai-town", "data", "quests.json")
        quests_path = os.path.normpath(quests_path)
        
        if not os.path.exists(quests_path):
            return {}
        
        with open(quests_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"[WARN] 加载任务数据失败: {e}")
        return {}

def get_quest_keywords_for_npc(npc_name: str) -> List[List[str]]:
    """获取指定NPC的所有任务关键词（同义词组）
    
    Args:
        npc_name: NPC名称
    
    Returns:
        关键词列表，每个元素是一个同义词组（列表）
    """
    quests_data = _load_quests_data()
    if not quests_data:
        return []
    
    keywords = []
    for quest_id, quest in quests_data.items():
        # 只获取对话任务且匹配NPC的关键词
        if quest.get("type") == "dialogue" and quest.get("npc") == npc_name:
            quest_keywords = quest.get("keywords", [])
            for keyword_group in quest_keywords:
                # 支持两种格式：字符串或数组
                if isinstance(keyword_group, list):
                    keywords.append(keyword_group)
                else:
                    # 向后兼容：单个字符串也当作数组处理
                    keywords.append([keyword_group])
    
    return keywords

def find_quests_for_matched_keyword(npc_name: str, matched_keyword: str) -> List[str]:
    """查找匹配关键词对应的任务ID列表
    
    Args:
        npc_name: NPC名称
        matched_keyword: 匹配到的关键词（主关键词）
    
    Returns:
        任务ID列表
    """
    quests_data = _load_quests_data()
    if not quests_data:
        return []
    
    matched_quest_ids = []
    for quest_id, quest in quests_data.items():
        if quest.get("type") == "dialogue" and quest.get("npc") == npc_name:
            quest_keywords = quest.get("keywords", [])
            for keyword_group in quest_keywords:
                keyword_list = keyword_group if isinstance(keyword_group, list) else [keyword_group]
                # 检查匹配的关键词是否在这个同义词组中，或者是否是该组的主关键词
                if matched_keyword in keyword_list or (len(keyword_list) > 0 and matched_keyword == keyword_list[0]):
                    if quest_id not in matched_quest_ids:
                        matched_quest_ids.append(quest_id)
                    break
    
    return matched_quest_ids

@app.get("/health")
async def health_check():
    """健康检查"""
    return {"status": "healthy", "timestamp": "now"}

@app.post("/chat", response_model=ChatResponse)
async def chat_with_npc(request: ChatRequest):
    """与NPC对话接口
    
    玩家与指定NPC进行实时对话,使用独立的Agent处理
    """
    npc_mgr, _, _ = get_managers()
    
    # 验证NPC是否存在
    npc_info = npc_mgr.get_npc_info(request.npc_name)
    if not npc_info:
        raise HTTPException(
            status_code=404,
            detail=f"NPC '{request.npc_name}' 不存在"
        )
    
    try:
        # 调用NPC Agent处理对话
        response_text = npc_mgr.chat(request.npc_name, request.message)
        
        # ⭐ 获取该NPC的任务关键词，进行语义匹配（仅当前端未匹配到时使用）
        # 注意：这里我们总是进行语义匹配，但前端会先尝试同义词匹配
        # 如果前端匹配成功，前端会忽略后端返回的 matched_keywords
        keywords = get_quest_keywords_for_npc(request.npc_name)
        matched_keywords = []
        if keywords:
            # 调用语义匹配（如果LLM可用）
            matched_keywords = npc_mgr.check_keywords_in_response(
                request.npc_name,
                response_text,
                keywords
            )
            if matched_keywords:
                print(f"[INFO] 后端语义匹配到关键词: {matched_keywords}")
        
        return ChatResponse(
            npc_name=request.npc_name,
            npc_title=npc_info["title"],
            message=response_text,
            matched_keywords=matched_keywords,
            success=True
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"对话处理失败: {str(e)}"
        )

@app.get("/npcs", response_model=NPCListResponse)
async def list_npcs():
    """获取所有NPC列表"""
    npc_mgr, _, _ = get_managers()
    
    npcs_data = npc_mgr.get_all_npcs()
    npcs = [NPCInfo(**npc) for npc in npcs_data]
    
    return NPCListResponse(
        npcs=npcs,
        total=len(npcs)
    )

@app.get("/npcs/status", response_model=NPCStatusResponse)
async def get_npcs_status():
    """获取所有NPC的当前状态
    
    返回批量生成的NPC对话内容,用于显示NPC的自主行为
    """
    _, state_mgr, _ = get_managers()
    
    state = state_mgr.get_current_state()
    
    return NPCStatusResponse(
        dialogues=state["dialogues"],
        last_update=state["last_update"],
        next_update_in=state["next_update_in"]
    )

@app.post("/npcs/status/refresh")
async def refresh_npcs_status():
    """强制刷新NPC状态
    
    立即触发一次批量对话生成
    """
    _, state_mgr, _ = get_managers()
    
    await state_mgr.force_update()
    state = state_mgr.get_current_state()
    
    return {
        "message": "NPC状态已刷新",
        "dialogues": state["dialogues"]
    }

@app.get("/npcs/{npc_name}")
async def get_npc_info(npc_name: str):
    """获取指定NPC的详细信息"""
    npc_mgr, state_mgr, _ = get_managers()

    npc_info = npc_mgr.get_npc_info(npc_name)
    if not npc_info:
        raise HTTPException(
            status_code=404,
            detail=f"NPC '{npc_name}' 不存在"
        )

    # 添加当前对话
    current_dialogue = state_mgr.get_npc_dialogue(npc_name)
    npc_info["current_dialogue"] = current_dialogue

    return npc_info

@app.get("/npcs/{npc_name}/memories")
async def get_npc_memories(npc_name: str, limit: int = 10):
    """获取NPC的记忆列表

    Args:
        npc_name: NPC名称
        limit: 返回的记忆数量限制 (默认10条)

    Returns:
        NPC的记忆列表
    """
    npc_mgr, _, _ = get_managers()

    # 验证NPC是否存在
    npc_info = npc_mgr.get_npc_info(npc_name)
    if not npc_info:
        raise HTTPException(
            status_code=404,
            detail=f"NPC '{npc_name}' 不存在"
        )

    try:
        memories = npc_mgr.get_npc_memories(npc_name, limit=limit)

        return {
            "npc_name": npc_name,
            "memories": memories,
            "total": len(memories)
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"获取记忆失败: {str(e)}"
        )

@app.delete("/npcs/{npc_name}/memories")
async def clear_npc_memories(npc_name: str, memory_type: str = None):
    """清空NPC的记忆 (用于测试)

    Args:
        npc_name: NPC名称
        memory_type: 记忆类型 (working/episodic), 不指定则清空所有

    Returns:
        操作结果
    """
    npc_mgr, _, _ = get_managers()

    # 验证NPC是否存在
    npc_info = npc_mgr.get_npc_info(npc_name)
    if not npc_info:
        raise HTTPException(
            status_code=404,
            detail=f"NPC '{npc_name}' 不存在"
        )

    try:
        npc_mgr.clear_npc_memory(npc_name, memory_type)

        return {
            "message": f"已清空{npc_name}的记忆",
            "npc_name": npc_name,
            "memory_type": memory_type or "all"
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"清空记忆失败: {str(e)}"
        )

@app.get("/npcs/{npc_name}/affinity")
async def get_npc_affinity(npc_name: str, player_id: str = "player"):
    """获取NPC对玩家的好感度

    Args:
        npc_name: NPC名称
        player_id: 玩家ID (默认为"player")

    Returns:
        好感度信息
    """
    npc_mgr, _, _ = get_managers()

    # 验证NPC是否存在
    npc_info = npc_mgr.get_npc_info(npc_name)
    if not npc_info:
        raise HTTPException(
            status_code=404,
            detail=f"NPC '{npc_name}' 不存在"
        )

    try:
        affinity_info = npc_mgr.get_npc_affinity(npc_name, player_id)

        return {
            "npc_name": npc_name,
            "player_id": player_id,
            **affinity_info
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"获取好感度失败: {str(e)}"
        )

@app.get("/affinities")
async def get_all_affinities(player_id: str = "player"):
    """获取所有NPC对玩家的好感度

    Args:
        player_id: 玩家ID (默认为"player")

    Returns:
        所有NPC的好感度信息
    """
    npc_mgr, _, _ = get_managers()

    try:
        affinities = npc_mgr.get_all_affinities(player_id)

        return {
            "player_id": player_id,
            "affinities": affinities
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"获取好感度失败: {str(e)}"
        )

@app.get("/quizzes/generated", response_model=GeneratedQuizResponse)
async def generate_quiz(
    npc_name: str,
    count: int = 3,
    quiz_id: str | None = None,
):
    """根据 NPC 名称与可选 quiz_id 动态生成答题题目

    当前实现使用 QuizGenerator 骨架, 返回结构正确的占位结果。
    后续任务将补充实际的 LLM 生成与记忆集成逻辑。
    """
    # 简单参数校验
    if count <= 0:
        raise HTTPException(status_code=400, detail="count 必须大于 0")

    # 验证 NPC 是否存在, 复用现有 npc_manager
    npc_mgr, _, quiz_gen = get_managers()
    npc_info = npc_mgr.get_npc_info(npc_name)
    if not npc_info:
        raise HTTPException(
            status_code=404,
            detail=f"NPC '{npc_name}' 不存在",
        )

    real_quiz_id = quiz_id or ""

    try:
        log_quiz_generation_start(real_quiz_id, npc_name)
        result = quiz_gen.generate_quiz(npc_name=npc_name, count=count, quiz_id=real_quiz_id)
        log_quiz_generation_success(real_quiz_id, npc_name, len(result.questions))
        return result
    except Exception as exc:
        log_quiz_generation_failure(real_quiz_id, npc_name, "generator_error", exc)
        # 按规范, 失败时可以返回空 questions, 由前端决定是否回退本地题库
        return GeneratedQuizResponse(
            quiz_id=real_quiz_id,
            npc_name=npc_name,
            title=f"{npc_name}知识问答（动态生成）",
            questions=[],
        )

@app.put("/npcs/{npc_name}/affinity")
async def set_npc_affinity(npc_name: str, affinity: float, player_id: str = "player"):
    """设置NPC对玩家的好感度 (用于测试)
    
    Args:
        npc_name: NPC名称
        affinity: 好感度值 (0-100)
        player_id: 玩家ID (默认为"player")
    
    Returns:
        操作结果
    """
    npc_mgr, _, _ = get_managers()

    # 验证NPC是否存在
    npc_info = npc_mgr.get_npc_info(npc_name)
    if not npc_info:
        raise HTTPException(
            status_code=404,
            detail=f"NPC '{npc_name}' 不存在"
        )

    # 验证好感度范围
    if affinity < 0 or affinity > 100:
        raise HTTPException(
            status_code=400,
            detail="好感度必须在0-100之间"
        )

    try:
        npc_mgr.set_npc_affinity(npc_name, affinity, player_id)
        affinity_info = npc_mgr.get_npc_affinity(npc_name, player_id)

        return {
            "message": f"已设置{npc_name}对玩家的好感度",
            "npc_name": npc_name,
            "player_id": player_id,
            **affinity_info
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"设置好感度失败: {str(e)}"
        )


@app.websocket("/ws/dialogues")
async def dialogues_websocket(websocket: WebSocket):
    """接收外部应用推送的对话内容，并写入 NPC 的工作记忆"""
    await websocket.accept()
    npc_mgr, _, _ = get_managers()

    log_info("🌐 WebSocket 连接已建立: /ws/dialogues")
    
    # ⭐ 更新连接状态并通知前端
    async with external_dialogue_ws_lock:
        global external_dialogue_ws_connected
        external_dialogue_ws_connected = True
    
    # 广播连接状态给前端
    status_message = {
        "type": "external_dialogue_ws_status",
        "status": "connected",
        "message": "外部对话WebSocket已连接"
    }
    await quest_update_manager.broadcast_update(status_message)
    log_info("📡 已通知前端: 外部对话WebSocket连接成功")

    try:
        while True:
            # 使用 receive() 方法接收消息，可以处理不同类型的消息
            message = await websocket.receive()
            
            # 检查消息类型
            if "text" in message:
                message_text = message["text"]
            elif "bytes" in message:
                # 如果是二进制消息，尝试解码为文本
                try:
                    message_text = message["bytes"].decode("utf-8")
                except UnicodeDecodeError:
                    log_error(f"WS 收到无法解码的二进制消息")
                    continue
            else:
                # 忽略其他类型的消息（如 ping/pong）
                continue

            try:
                data = json.loads(message_text)
            except json.JSONDecodeError:
                log_error(f"WS 无效 JSON: {message_text[:100]}...")
                continue

            npc_name = data.get("npc_name")
            speaker = data.get("speaker")
            content = data.get("content")
            player_id = data.get("player_id", "player")
            timestamp = data.get("timestamp")

            if not npc_name or not isinstance(npc_name, str):
                log_error(f"WS 对话注入失败: 缺少有效 npc_name, data={data}")
                continue

            if speaker not in ("player", "npc"):
                log_error(f"WS 对话注入失败: 非法 speaker={speaker}, data={data}")
                continue

            if not content or not isinstance(content, str):
                log_error(f"WS 对话注入失败: 缺少 content, data={data}")
                continue

            # 验证 NPC 是否存在
            npc_info = npc_mgr.get_npc_info(npc_name)
            if not npc_info:
                log_error(f"WS 对话注入失败: 未知 NPC '{npc_name}'")
                continue

            try:
                npc_mgr.ingest_external_dialogue(
                    npc_name=npc_name,
                    speaker=speaker,
                    content=content,
                    player_id=player_id,
                    timestamp=timestamp,
                )
                
                # ⭐ 如果是NPC的回复，进行关键词匹配并广播任务更新
                if speaker == "npc":
                    keywords = get_quest_keywords_for_npc(npc_name)
                    if keywords:
                        matched_keywords = npc_mgr.check_keywords_in_response(
                            npc_name,
                            content,
                            keywords
                        )
                        if matched_keywords:
                            # 为每个匹配的关键词查找对应的任务并广播
                            for matched_keyword in matched_keywords:
                                matched_quest_ids = find_quests_for_matched_keyword(npc_name, matched_keyword)
                                for quest_id in matched_quest_ids:
                                    # 广播任务更新
                                    update_message = {
                                        "type": "quest_keyword_matched",
                                        "npc_name": npc_name,
                                        "quest_id": quest_id,
                                        "matched_keyword": matched_keyword,
                                        "content": content[:100]  # 只发送前100个字符
                                    }
                                    await quest_update_manager.broadcast_update(update_message)
                                    log_info(f"📡 任务更新已广播: quest_id={quest_id}, keyword={matched_keyword}")
                                
            except Exception as exc:
                log_error(f"WS 对话注入异常: npc={npc_name}, error={exc}")
                continue

    except WebSocketDisconnect:
        log_info("🌐 WebSocket 客户端断开连接: /ws/dialogues")
    except Exception as exc:
        log_error(f"WS 连接异常中断: {exc}")
    finally:
        # ⭐ 更新连接状态并通知前端
        async with external_dialogue_ws_lock:
            external_dialogue_ws_connected = False
        
        # 广播连接状态给前端
        status_message = {
            "type": "external_dialogue_ws_status",
            "status": "disconnected",
            "message": "外部对话WebSocket已断开"
        }
        await quest_update_manager.broadcast_update(status_message)
        log_info("📡 已通知前端: 外部对话WebSocket连接断开")
        
        try:
            await websocket.close()
        except RuntimeError:
            # 已关闭
            pass

@app.websocket("/ws/quest_updates")
async def quest_updates_websocket(websocket: WebSocket):
    """任务更新WebSocket端点 - 前端连接后接收任务进度更新通知"""
    await websocket.accept()
    connection_id = str(uuid.uuid4())
    
    log_info(f"🌐 任务更新WebSocket连接已建立: {connection_id}")
    
    try:
        await quest_update_manager.add_connection(connection_id, websocket)
        
        # 保持连接，等待广播消息
        while True:
            # 接收ping消息保持连接活跃
            try:
                message = await websocket.receive_text()
                # 可以处理客户端发送的心跳消息
                if message == "ping":
                    await websocket.send_text("pong")
            except WebSocketDisconnect:
                break
                
    except WebSocketDisconnect:
        log_info(f"🌐 任务更新WebSocket客户端断开连接: {connection_id}")
    except Exception as exc:
        log_error(f"📡 任务更新WebSocket连接异常: {exc}")
    finally:
        await quest_update_manager.remove_connection(connection_id)
        try:
            await websocket.close()
        except RuntimeError:
            # 已关闭
            pass

# ==================== 主程序入口 ====================

if __name__ == "__main__":
    print("\n🚀 启动后端服务...")
    print(f"📍 监听地址: {settings.API_HOST}:{settings.API_PORT}")
    print(f"📖 访问文档: http://localhost:{settings.API_PORT}/docs\n")
    
    uvicorn.run(
        "main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=True,  # 开发模式自动重载
        log_level="info"
    )

